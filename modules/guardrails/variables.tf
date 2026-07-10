variable "environment" {
  description = "Deployment environment. Drives the entire security posture matrix."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be exactly one of: dev, test, prod."
  }
}

variable "project" {
  description = "Project slug, used to derive resource names and tags."
  type        = string
  default     = "saas"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.project))
    error_message = "project must be 2-15 chars, lowercase alphanumeric or hyphen, starting with a letter."
  }
}

variable "sizing" {
  description = "Per-environment sizing overrides. Cost/capacity only -- never security."
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
  description = <<-EOT
    CIDRs permitted to reach the EKS public API endpoint. Only consulted when the
    environment's posture allows a public endpoint at all (dev). Ignored in
    staging/prod, where the endpoint is private-only and reached via Verified Access.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_public_access_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in allowed_public_access_cidrs must be a valid CIDR block."
  }

  validation {
    condition     = !contains(var.allowed_public_access_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is never an acceptable EKS public access CIDR, in any environment."
  }
}

variable "auth_provider" {
  description = "Which auth provider this environment deploys: 'keycloak' or 'auth-service'."
  type        = string
  default     = "keycloak"

  validation {
    condition     = contains(["keycloak", "auth-service"], var.auth_provider)
    error_message = "auth_provider must be 'keycloak' or 'auth-service'."
  }
}

variable "observability" {
  description = "Which observability stack this environment deploys: 'elk' or 'grafana'."
  type        = string
  default     = "elk"

  validation {
    condition     = contains(["elk", "grafana"], var.observability)
    error_message = "observability must be 'elk' or 'grafana'."
  }
}
