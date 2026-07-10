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

variable "keycloak_hostname" {
  type    = string
  default = "keycloak.internal"
}

variable "auth0_issuer" {
  type    = string
  default = ""
}

variable "auth0_client_id" {
  type    = string
  default = ""
}

variable "auth0_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "opensearch_master_username" {
  type      = string
  default   = "admin"
  sensitive = true
}

variable "opensearch_master_password" {
  type      = string
  default   = ""
  sensitive = true
}

# ── Inputs supplied by Terragrunt dependency blocks ──────────────────────────
# From 00-network:
variable "vpc_id" { type = string }
# From 10-platform:
variable "cluster_name" { type = string }
variable "cluster_endpoint" { type = string }
variable "cluster_ca" {
  type      = string
  sensitive = true
}
variable "eks_node_group" { type = any }
variable "karpenter_interruption_queue_name" { type = string }
# From 20-data:
variable "keycloak_db_endpoint" {
  type    = string
  default = ""
}
# From 40-observability:
variable "otel_collector_irsa_role_arn" {
  type    = string
  default = null
}
variable "prometheus_endpoint" {
  type    = string
  default = null
}
variable "opensearch_endpoint" {
  type    = string
  default = null
}
