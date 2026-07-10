terraform {
  required_version = ">= 1.3.0"
}

locals {
  env = var.environment

  # The security posture is a pure function of the environment. Callers may not
  # override any of it -- `var.sizing` exists for cost/capacity, and nothing else.
  security_matrix = {
    dev = {
      rds_deletion_protection   = false
      rds_multi_az              = false
      rds_storage_encrypted     = true
      rds_publicly_accessible   = false
      rds_iam_database_auth     = true
      rds_performance_insights  = false
      rds_backup_retention_days = 1
      rds_skip_final_snapshot   = true
      rds_copy_tags_to_snapshot = true

      msk_client_broker_encryption = "TLS"
      msk_in_cluster_encryption    = true
      msk_sasl_iam_enabled         = true
      msk_sasl_scram_enabled       = false
      msk_unauthenticated_access   = false
      msk_enhanced_monitoring      = "DEFAULT"

      elasticache_transit_encryption      = true
      elasticache_at_rest_encryption      = true
      elasticache_auth_token_enabled      = true
      elasticache_multi_az                = false
      elasticache_automatic_failover      = false
      elasticache_snapshot_retention_days = 0

      opensearch_encrypt_at_rest      = true
      opensearch_node_to_node_encrypt = true
      opensearch_enforce_https        = true
      opensearch_zone_awareness       = false

      eks_endpoint_private_access = true
      eks_endpoint_public_access  = true
      eks_secrets_kms_encryption  = true
      eks_control_plane_log_types = ["api", "audit"]
      eks_require_imdsv2          = true
      eks_node_public_ip          = false

      vpc_flow_logs_enabled       = true
      vpc_flow_logs_traffic_type  = "REJECT"
      vpc_single_nat_gateway      = true
      vpc_flow_log_retention_days = 14

      kms_key_rotation         = true
      kms_deletion_window_days = 7

      ecr_scan_on_push   = true
      ecr_immutable_tags = true
      ecr_kms_encryption = true

      verified_access_enabled           = false
      verified_access_logging           = true
      verified_access_log_trust_context = false
    }

    test = {
      rds_deletion_protection   = true
      rds_multi_az              = true
      rds_storage_encrypted     = true
      rds_publicly_accessible   = false
      rds_iam_database_auth     = true
      rds_performance_insights  = true
      rds_backup_retention_days = 7
      rds_skip_final_snapshot   = false
      rds_copy_tags_to_snapshot = true

      msk_client_broker_encryption = "TLS"
      msk_in_cluster_encryption    = true
      msk_sasl_iam_enabled         = true
      msk_sasl_scram_enabled       = false
      msk_unauthenticated_access   = false
      msk_enhanced_monitoring      = "PER_BROKER"

      elasticache_transit_encryption      = true
      elasticache_at_rest_encryption      = true
      elasticache_auth_token_enabled      = true
      elasticache_multi_az                = true
      elasticache_automatic_failover      = true
      elasticache_snapshot_retention_days = 3

      opensearch_encrypt_at_rest      = true
      opensearch_node_to_node_encrypt = true
      opensearch_enforce_https        = true
      opensearch_zone_awareness       = true

      eks_endpoint_private_access = true
      eks_endpoint_public_access  = false
      eks_secrets_kms_encryption  = true
      eks_control_plane_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      eks_require_imdsv2          = true
      eks_node_public_ip          = false

      vpc_flow_logs_enabled       = true
      vpc_flow_logs_traffic_type  = "ALL"
      vpc_single_nat_gateway      = false
      vpc_flow_log_retention_days = 90

      kms_key_rotation         = true
      kms_deletion_window_days = 30

      ecr_scan_on_push   = true
      ecr_immutable_tags = true
      ecr_kms_encryption = true

      verified_access_enabled           = true
      verified_access_logging           = true
      verified_access_log_trust_context = true
    }

    prod = {
      rds_deletion_protection   = true
      rds_multi_az              = true
      rds_storage_encrypted     = true
      rds_publicly_accessible   = false
      rds_iam_database_auth     = true
      rds_performance_insights  = true
      rds_backup_retention_days = 35
      rds_skip_final_snapshot   = false
      rds_copy_tags_to_snapshot = true

      msk_client_broker_encryption = "TLS"
      msk_in_cluster_encryption    = true
      msk_sasl_iam_enabled         = true
      msk_sasl_scram_enabled       = true
      msk_unauthenticated_access   = false
      msk_enhanced_monitoring      = "PER_TOPIC_PER_PARTITION"

      elasticache_transit_encryption      = true
      elasticache_at_rest_encryption      = true
      elasticache_auth_token_enabled      = true
      elasticache_multi_az                = true
      elasticache_automatic_failover      = true
      elasticache_snapshot_retention_days = 7

      opensearch_encrypt_at_rest      = true
      opensearch_node_to_node_encrypt = true
      opensearch_enforce_https        = true
      opensearch_zone_awareness       = true

      eks_endpoint_private_access = true
      eks_endpoint_public_access  = false
      eks_secrets_kms_encryption  = true
      eks_control_plane_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      eks_require_imdsv2          = true
      eks_node_public_ip          = false

      vpc_flow_logs_enabled       = true
      vpc_flow_logs_traffic_type  = "ALL"
      vpc_single_nat_gateway      = false
      vpc_flow_log_retention_days = 365

      kms_key_rotation         = true
      kms_deletion_window_days = 30

      ecr_scan_on_push   = true
      ecr_immutable_tags = true
      ecr_kms_encryption = true

      verified_access_enabled           = true
      verified_access_logging           = true
      verified_access_log_trust_context = true
    }
  }

  security = local.security_matrix[local.env]

  sizing_defaults = {
    dev = {
      rds_instance_class        = "db.t4g.micro"
      rds_allocated_storage     = 20
      msk_broker_instance_type  = "kafka.t3.small"
      msk_broker_count          = 2
      elasticache_node_type     = "cache.t4g.micro"
      elasticache_num_replicas  = 0
      opensearch_instance_type  = "t3.small.search"
      opensearch_instance_count = 1
      opensearch_volume_size    = 10
      eks_node_instance_types   = ["t3.medium"]
      eks_node_min_size         = 1
      eks_node_max_size         = 5
      eks_node_desired_size     = 2
    }
    test = {
      rds_instance_class        = "db.t4g.medium"
      rds_allocated_storage     = 100
      msk_broker_instance_type  = "kafka.m7g.large"
      msk_broker_count          = 3
      elasticache_node_type     = "cache.m7g.large"
      elasticache_num_replicas  = 1
      opensearch_instance_type  = "m6g.large.search"
      opensearch_instance_count = 2
      opensearch_volume_size    = 50
      eks_node_instance_types   = ["m6i.large"]
      eks_node_min_size         = 2
      eks_node_max_size         = 8
      eks_node_desired_size     = 3
    }
    prod = {
      rds_instance_class        = "db.m7g.large"
      rds_allocated_storage     = 500
      msk_broker_instance_type  = "kafka.m7g.large"
      msk_broker_count          = 3
      elasticache_node_type     = "cache.r7g.large"
      elasticache_num_replicas  = 2
      opensearch_instance_type  = "m6g.large.search"
      opensearch_instance_count = 3
      opensearch_volume_size    = 200
      eks_node_instance_types   = ["m6i.xlarge"]
      eks_node_min_size         = 3
      eks_node_max_size         = 20
      eks_node_desired_size     = 6
    }
  }

  sizing = {
    for k, v in local.sizing_defaults[local.env] :
    k => coalesce(try(var.sizing[k], null), v)
  }

  name_prefix = "${var.project}-${local.env}"

  common_tags = {
    Project     = var.project
    Environment = local.env
    ManagedBy   = "terraform"
    Repo        = "saas-services-infra"
    DataClass   = local.env == "prod" ? "confidential" : "internal"
  }
}

resource "terraform_data" "guardrail_invariants" {
  input = local.env

  lifecycle {
    precondition {
      condition     = local.security.rds_storage_encrypted
      error_message = "INVARIANT: RDS storage encryption cannot be disabled in any environment."
    }

    precondition {
      condition     = local.security.rds_publicly_accessible == false
      error_message = "INVARIANT: RDS instances must never be publicly accessible."
    }

    precondition {
      condition     = local.env == "dev" || local.security.rds_deletion_protection
      error_message = "INVARIANT: test and prod RDS must enable deletion protection."
    }

    precondition {
      condition     = local.env == "dev" || local.security.rds_multi_az
      error_message = "INVARIANT: test and prod RDS must be Multi-AZ."
    }

    precondition {
      condition     = local.env != "prod" || local.security.rds_backup_retention_days >= 30
      error_message = "INVARIANT: prod RDS backup retention must be >= 30 days."
    }

    precondition {
      condition     = local.security.msk_client_broker_encryption == "TLS"
      error_message = "INVARIANT: MSK client-broker encryption must be TLS. PLAINTEXT and TLS_PLAINTEXT are forbidden."
    }

    precondition {
      condition     = local.security.msk_unauthenticated_access == false
      error_message = "INVARIANT: MSK unauthenticated access must never be enabled."
    }

    precondition {
      condition     = local.security.msk_sasl_iam_enabled || local.security.msk_sasl_scram_enabled
      error_message = "INVARIANT: MSK must have at least one SASL mechanism (IAM or SCRAM) enabled."
    }

    precondition {
      condition     = local.env != "prod" || local.sizing.msk_broker_count >= 3
      error_message = "INVARIANT: prod MSK requires >= 3 brokers to sustain replication factor 3 with min.insync.replicas=2."
    }

    precondition {
      condition     = local.security.elasticache_transit_encryption
      error_message = "INVARIANT: ElastiCache in-transit encryption cannot be disabled."
    }

    precondition {
      condition     = local.security.elasticache_at_rest_encryption
      error_message = "INVARIANT: ElastiCache at-rest encryption cannot be disabled."
    }

    precondition {
      condition     = local.security.elasticache_auth_token_enabled
      error_message = "INVARIANT: ElastiCache AUTH must be enabled; a security group is not authentication."
    }

    precondition {
      condition     = local.security.elasticache_multi_az == false || local.security.elasticache_automatic_failover
      error_message = "INVARIANT: Multi-AZ requires automatic_failover; AWS rejects the combination otherwise."
    }

    precondition {
      condition     = local.env == "dev" || local.security.elasticache_multi_az
      error_message = "INVARIANT: test and prod ElastiCache must be Multi-AZ."
    }

    precondition {
      condition     = local.security.elasticache_automatic_failover == false || local.sizing.elasticache_num_replicas >= 1
      error_message = "INVARIANT: automatic_failover requires at least one read replica to fail over to."
    }

    precondition {
      condition     = local.security.opensearch_encrypt_at_rest && local.security.opensearch_node_to_node_encrypt
      error_message = "INVARIANT: OpenSearch at-rest and node-to-node encryption are mandatory."
    }

    precondition {
      condition     = local.security.opensearch_enforce_https
      error_message = "INVARIANT: OpenSearch must enforce HTTPS."
    }

    precondition {
      condition     = local.env == "dev" || local.security.opensearch_zone_awareness
      error_message = "INVARIANT: test and prod OpenSearch must enable zone awareness."
    }

    precondition {
      condition     = local.env == "dev" || local.sizing.opensearch_instance_count >= 2
      error_message = "INVARIANT: OpenSearch zone awareness requires an even/multi-node cluster; instance_count must be >= 2 outside dev."
    }

    precondition {
      condition     = local.security.eks_endpoint_private_access
      error_message = "INVARIANT: the EKS private endpoint must always be enabled."
    }

    precondition {
      condition     = local.env == "dev" || local.security.eks_endpoint_public_access == false
      error_message = "INVARIANT: test and prod EKS API endpoints must be private-only (reach them via Verified Access)."
    }

    precondition {
      condition     = local.env != "dev" || length(var.allowed_public_access_cidrs) > 0
      error_message = "dev enables the public EKS endpoint, so allowed_public_access_cidrs must be a non-empty allow-list."
    }

    # The private-only endpoint is only reachable if something fronts it. Without
    # this pairing, test/prod would come up with an unreachable control plane.
    precondition {
      condition     = local.security.eks_endpoint_public_access || local.security.verified_access_enabled
      error_message = "INVARIANT: a private-only EKS endpoint requires Verified Access to be enabled, or the API is unreachable."
    }

    precondition {
      condition     = local.security.eks_secrets_kms_encryption
      error_message = "INVARIANT: EKS secret envelope encryption with KMS is mandatory."
    }

    precondition {
      condition     = local.security.eks_require_imdsv2
      error_message = "INVARIANT: IMDSv2 must be required on all node groups (blocks SSRF credential theft)."
    }

    precondition {
      condition     = contains(local.security.eks_control_plane_log_types, "audit")
      error_message = "INVARIANT: the EKS 'audit' control-plane log must be enabled in every environment."
    }

    precondition {
      condition     = local.sizing.eks_node_min_size <= local.sizing.eks_node_desired_size && local.sizing.eks_node_desired_size <= local.sizing.eks_node_max_size
      error_message = "INVARIANT: eks node sizing must satisfy min <= desired <= max."
    }

    precondition {
      condition     = local.env != "prod" || local.sizing.eks_node_min_size >= 3
      error_message = "INVARIANT: prod EKS node group min_size must be >= 3 (one schedulable node per AZ)."
    }

    precondition {
      condition     = local.security.vpc_flow_logs_enabled
      error_message = "INVARIANT: VPC flow logs are mandatory in every environment."
    }

    precondition {
      condition     = local.env == "dev" || local.security.vpc_single_nat_gateway == false
      error_message = "INVARIANT: test and prod require one NAT gateway per AZ (no cross-AZ SPOF)."
    }

    precondition {
      condition     = local.security.kms_key_rotation
      error_message = "INVARIANT: automatic KMS key rotation is mandatory."
    }

    precondition {
      condition     = local.security.ecr_immutable_tags
      error_message = "INVARIANT: ECR image tags must be immutable; a mutable tag defeats image provenance."
    }

    precondition {
      condition     = local.security.ecr_scan_on_push && local.security.ecr_kms_encryption
      error_message = "INVARIANT: ECR must scan on push and encrypt with a customer-managed KMS key."
    }
  }
}
