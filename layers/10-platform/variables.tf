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

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.32"
}

# ── Inputs supplied by Terragrunt dependency blocks (from 00-network) ─────────
variable "cluster_name" {
  description = "Physical cluster name prefix. From 00-network."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "kms_key_arn" {
  description = "Shared customer-managed key. From 00-network."
  type        = string
}

variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted EKS cluster admin via access entries (in addition to the Terraform caller role)."
  type        = list(string)
  default     = []
}
