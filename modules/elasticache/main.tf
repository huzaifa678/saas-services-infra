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

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-subnet-group" })
}

# A security group is not authentication. Transit encryption is a precondition of
# using an AUTH token at all -- ElastiCache rejects the pairing otherwise.
resource "random_password" "auth_token" {
  count = var.auth_token_enabled ? 1 : 0

  length           = 64
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_secretsmanager_secret" "auth_token" {
  count = var.auth_token_enabled ? 1 : 0

  name                    = "${var.name}-auth-token"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "auth_token" {
  count = var.auth_token_enabled ? 1 : 0

  secret_id     = aws_secretsmanager_secret.auth_token[0].id
  secret_string = random_password.auth_token[0].result
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = "Redis cluster for SAAS services"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_node_groups            = 1
  replicas_per_node_group    = var.num_replicas
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.redis_sg_id]
  port                       = 6379
  parameter_group_name       = var.parameter_group_name
  apply_immediately          = var.apply_immediately

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  kms_key_id                 = var.kms_key_arn
  auth_token                 = var.auth_token_enabled ? random_password.auth_token[0].result : null

  snapshot_retention_limit = var.snapshot_retention_days

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = var.transit_encryption_enabled && var.at_rest_encryption_enabled
      error_message = "INVARIANT: ElastiCache encryption in transit and at rest cannot be disabled."
    }

    precondition {
      condition     = var.auth_token_enabled == false || var.transit_encryption_enabled
      error_message = "An AUTH token requires transit encryption; ElastiCache rejects the pairing otherwise."
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
  }
}
