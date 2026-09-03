variable "project" {
  description = "Project slug. Drives tags and the guardrails name prefix."
  type        = string
  default     = "saas"
}

variable "environment" {
  description = "dev | staging | prod. Selects the entire security posture."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "capacity_tier" {
  description = "Named capacity/scale tier (cost only). Passed through to guardrails; null => the env's default rung."
  type        = string
  default     = null
}

variable "sizing" {
  description = "Per-environment sizing overrides. Cost/capacity only."
  type = object({
    rds_instance_class        = optional(string)
    rds_allocated_storage     = optional(number)
    msk_broker_instance_type  = optional(string)
    msk_broker_count          = optional(number)
    elasticache_node_type     = optional(string)
    elasticache_num_replicas  = optional(number)
    opensearch_instance_type  = optional(string)
    opensearch_instance_count = optional(number)
    opensearch_volume_size    = optional(number)
    eks_node_instance_types   = optional(list(string))
    eks_node_min_size         = optional(number)
    eks_node_max_size         = optional(number)
    eks_node_desired_size     = optional(number)
  })
  default = {}
}

variable "allowed_public_access_cidrs" {
  description = "CIDRs permitted to reach the EKS public API endpoint (dev only)."
  type        = list(string)
  default     = []
}

variable "auth_provider" {
  description = "keycloak | auth-service"
  type        = string
  default     = "keycloak"
}

variable "observability" {
  description = "elk | grafana"
  type        = string
  default     = "elk"
}

# opensearch_master_username / opensearch_master_password are read from the
# Secrets Manager secret "saas/<env>/opensearch-master" (see main.tf local.opensearch),
# not passed from CI.

# ── Inputs supplied by Terragrunt dependency blocks ──────────────────────────
# From 00-network:
variable "private_subnets" { type = list(string) }
# From 10-platform:
variable "oidc_provider_arn" { type = string }
variable "oidc_issuer" { type = string }
# From 20-data:
variable "opensearch_sg_id" { type = string }
