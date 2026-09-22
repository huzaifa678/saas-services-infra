terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
}

locals {
  # `num_node_groups > 1` is Redis Cluster mode: the keyspace is split across
  # shards by 16384 hash slots (CRC16), and AWS moves whole slot ranges during
  # online resharding. num_shards == 1 keeps the exact single-shard,
  # cluster-mode-disabled behaviour this module has always had.
  cluster_mode_enabled = var.num_shards > 1

  # Cluster mode requires a `.cluster.on` parameter group family. Preserve the
  # historical default group for the single-shard case so a 1-shard cluster is
  # byte-for-byte what it was before this capability landed.
  parameter_group_name = coalesce(
    var.parameter_group_name,
    local.cluster_mode_enabled ? "default.redis7.cluster.on" : "default.redis7",
  )

  # RBAC (user groups) and the legacy single AUTH token are mutually exclusive on
  # ElastiCache -- a replication group authenticates with ONE of them. When RBAC
  # is on, per-service users (created out-of-band by Crossplane) authenticate,
  # and the shared AUTH token is not issued.
  auth_token_active = var.auth_token_enabled && var.rbac_enabled == false
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-subnet-group" })
}

# A security group is not authentication. Transit encryption is a precondition of
# using an AUTH token at all -- ElastiCache rejects the pairing otherwise.
resource "random_password" "auth_token" {
  count = local.auth_token_active ? 1 : 0

  length           = 64
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_secretsmanager_secret" "auth_token" {
  count = local.auth_token_active ? 1 : 0

  name                    = "${var.name}-auth-token"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "auth_token" {
  count = local.auth_token_active ? 1 : 0

  secret_id     = aws_secretsmanager_secret.auth_token[0].id
  secret_string = random_password.auth_token[0].result
}


# Foundation for self-service cache tenants. Every user group MUST contain a user
# named "default"; we seed a DISABLED default (`off -@all`) so only named,
# key-prefix-scoped users can authenticate. Per-service users are created by
# Crossplane (provider-aws elasticache.User) and added to this group -- hence the
# `ignore_changes` on membership below, so Terraform seeds the group but does not
# fight the controller that manages its members.
resource "aws_elasticache_user" "default" {
  count = var.rbac_enabled ? 1 : 0

  user_id       = "${var.name}-default"
  user_name     = "default"
  access_string = "off -@all"
  engine        = "redis"

  authentication_mode {
    type = "no-password-required"
  }

  tags = var.tags
}

resource "aws_elasticache_user_group" "this" {
  count = var.rbac_enabled ? 1 : 0

  user_group_id = var.name
  engine        = "redis"
  user_ids      = [aws_elasticache_user.default[0].user_id]
  tags          = var.tags

  lifecycle {
    # Per-service tenant users are added to this group by Crossplane. Terraform
    # owns the group's existence and its default user, not its evolving roster.
    ignore_changes = [user_ids]
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = "Redis cluster for SAAS services"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_node_groups            = var.num_shards
  replicas_per_node_group    = var.num_replicas
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.redis_sg_id]
  port                       = 6379
  parameter_group_name       = local.parameter_group_name
  apply_immediately          = var.apply_immediately

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  kms_key_id                 = var.kms_key_arn
  auth_token                 = local.auth_token_active ? random_password.auth_token[0].result : null
  user_group_ids             = var.rbac_enabled ? [aws_elasticache_user_group.this[0].user_group_id] : null

  snapshot_retention_limit = var.snapshot_retention_days

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = var.transit_encryption_enabled && var.at_rest_encryption_enabled
      error_message = "INVARIANT: ElastiCache encryption in transit and at rest cannot be disabled."
    }

    precondition {
      condition     = local.auth_token_active == false || var.transit_encryption_enabled
      error_message = "An AUTH token requires transit encryption; ElastiCache rejects the pairing otherwise."
    }

    # RBAC uses per-user auth, not the single shared token. Attempting both is an
    # error ElastiCache rejects -- catch it here with a clear message.
    precondition {
      condition     = var.rbac_enabled == false || var.auth_token_enabled == false
      error_message = "rbac_enabled and auth_token_enabled are mutually exclusive; RBAC replaces the shared AUTH token with per-user credentials."
    }

    # RBAC over the wire still requires transit encryption.
    precondition {
      condition     = var.rbac_enabled == false || var.transit_encryption_enabled
      error_message = "rbac_enabled requires transit encryption."
    }

    # AWS rejects multi_az_enabled without automatic_failover_enabled, and
    # automatic_failover requires at least one replica to fail over to.
    precondition {
      condition     = var.multi_az_enabled == false || var.automatic_failover_enabled
      error_message = "multi_az_enabled requires automatic_failover_enabled."
    }

    precondition {
      condition     = var.automatic_failover_enabled == false || var.num_replicas >= 1
      error_message = "automatic_failover_enabled requires at least one read replica."
    }

    # Cluster mode (>1 shard) has no non-failover form on ElastiCache: each shard
    # is a primary, and AWS requires automatic failover across the shard set.
    precondition {
      condition     = local.cluster_mode_enabled == false || var.automatic_failover_enabled
      error_message = "num_shards > 1 (cluster mode) requires automatic_failover_enabled."
    }
  }
}


# ElastiCache Auto Scaling is the managed replacement for hand-rolled sharding:
# AWS adds/removes shards (or replicas) to hold a target metric, doing the online
# resharding for you. Requires cluster mode; scoped to num_shards > 1.

# Shard (node group) scaling on memory pressure.
resource "aws_appautoscaling_target" "shards" {
  count = var.autoscaling_enabled && local.cluster_mode_enabled ? 1 : 0

  service_namespace  = "elasticache"
  resource_id        = "replication-group/${aws_elasticache_replication_group.this.replication_group_id}"
  scalable_dimension = "elasticache:replication-group:NodeGroups"
  min_capacity       = var.autoscaling_min_shards
  max_capacity       = var.autoscaling_max_shards
}

resource "aws_appautoscaling_policy" "shards" {
  count = var.autoscaling_enabled && local.cluster_mode_enabled ? 1 : 0

  name               = "${var.name}-shard-memory-target"
  service_namespace  = aws_appautoscaling_target.shards[0].service_namespace
  resource_id        = aws_appautoscaling_target.shards[0].resource_id
  scalable_dimension = aws_appautoscaling_target.shards[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ElastiCacheDatabaseCapacityUsageCountedForEvictPercentage"
    }
    target_value       = var.autoscaling_target_memory_percent
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}

# Replica scaling on CPU: adds read replicas per shard under read load.
resource "aws_appautoscaling_target" "replicas" {
  count = var.autoscaling_replicas_enabled && local.cluster_mode_enabled ? 1 : 0

  service_namespace  = "elasticache"
  resource_id        = "replication-group/${aws_elasticache_replication_group.this.replication_group_id}"
  scalable_dimension = "elasticache:replication-group:Replicas"
  min_capacity       = var.autoscaling_min_replicas
  max_capacity       = var.autoscaling_max_replicas
}

resource "aws_appautoscaling_policy" "replicas" {
  count = var.autoscaling_replicas_enabled && local.cluster_mode_enabled ? 1 : 0

  name               = "${var.name}-replica-cpu-target"
  service_namespace  = aws_appautoscaling_target.replicas[0].service_namespace
  resource_id        = aws_appautoscaling_target.replicas[0].resource_id
  scalable_dimension = aws_appautoscaling_target.replicas[0].scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ElastiCacheReplicaEngineCPUUtilization"
    }
    target_value       = var.autoscaling_target_cpu_percent
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}
