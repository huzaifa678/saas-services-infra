variable "stack" {
  type        = string
  description = "Observability stack to deploy: 'grafana' or 'elk'"

  validation {
    condition     = contains(["grafana", "elk"], var.stack)
    error_message = "stack must be 'grafana' or 'elk'."
  }
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN from EKS module"
}

variable "oidc_issuer" {
  type        = string
  description = "OIDC issuer URL from EKS module"
}

# Grafana-specific
variable "grafana_workspace_name" {
  type    = string
  default = "saas-grafana"
}

# ELK-specific
variable "elk_domain_name" {
  type    = string
  default = "saas-opensearch"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs (required when stack = 'elk')"
  default     = []
}

variable "opensearch_sg_id" {
  type        = string
  description = "Security group ID for OpenSearch (required when stack = 'elk')"
  default     = ""
}

variable "opensearch_master_username" {
  type      = string
  default   = ""
  sensitive = true
}

variable "opensearch_master_password" {
  type      = string
  default   = ""
  sensitive = true
}
