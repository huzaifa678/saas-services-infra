plugin "aws" {
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
  version = "0.38.0"
  enabled = true

  deep_check = true
}

config {
  call_module_type = "all"
}

# ── Core rules ────────────────────────────────────────────────────────────────

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = false # variables lack descriptions — suppress noise
}

rule "terraform_documented_outputs" {
  enabled = false
}

# ── AWS: instance / node types ────────────────────────────────────────────────
# Validates that EC2, RDS, ElastiCache, MSK instance types actually exist.

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_db_instance_invalid_engine_version" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_elasticache_replication_group_invalid_type" {
  enabled = true
}

# ── AWS: EKS ──────────────────────────────────────────────────────────────────

rule "aws_eks_cluster_invalid_version" {
  enabled = true
}

rule "aws_eks_node_group_invalid_ami_type" {
  enabled = true
}

# ── AWS: IAM ──────────────────────────────────────────────────────────────────

rule "aws_iam_role_invalid_assume_role_policy" {
  enabled = true
}

# ── AWS: Security Groups ──────────────────────────────────────────────────────

rule "aws_security_group_invalid_protocol" {
  enabled = true
}

# ── AWS: ECR ─────────────────────────────────────────────────────────────────

rule "aws_ecr_repository_invalid_image_tag_mutability" {
  enabled = true
}

# ── AWS: MSK ─────────────────────────────────────────────────────────────────

rule "aws_msk_cluster_invalid_kafka_version" {
  enabled = true
}

# ── AWS: OpenSearch ───────────────────────────────────────────────────────────

rule "aws_opensearch_domain_invalid_engine_version" {
  enabled = true
}

# ── AWS: Grafana / Prometheus ─────────────────────────────────────────────────

rule "aws_grafana_workspace_invalid_account_access_type" {
  enabled = true
}

rule "aws_grafana_workspace_invalid_permission_type" {
  enabled = true
}
