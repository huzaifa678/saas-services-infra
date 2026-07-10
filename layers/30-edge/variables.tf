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

variable "eks_api_cidr" {
  description = <<-EOT
    Address range the Verified Access cidr endpoint forwards to. Must contain the
    private EKS API ENIs. Defaults to the whole VPC CIDR from the network layer.
  EOT
  type        = string
  default     = null
}

variable "ava_custom_subdomain" {
  description = "Public subdomain AVA serves cidr endpoints under. Required when Verified Access is enabled."
  type        = string
  default     = null
}

variable "ava_oidc_issuer" {
  description = "OIDC issuer URL for the Verified Access trust provider."
  type        = string
  default     = ""
}

variable "ava_oidc_client_id" {
  description = "OIDC client id for the Verified Access trust provider."
  type        = string
  default     = ""
}

variable "ava_oidc_client_secret" {
  description = "OIDC client secret for the Verified Access trust provider."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ava_policy_document" {
  description = <<-EOT
    Cedar policy gating access to the EKS API. The module rejects an unconditional
    `when { true }` permit: authenticating a user and then authorising everyone is
    not zero trust.
  EOT
  type        = string
  default     = ""
}

# ── Inputs supplied by Terragrunt dependency blocks (from 00-network) ─────────
variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnets" { type = list(string) }
variable "kms_key_arn" { type = string }
