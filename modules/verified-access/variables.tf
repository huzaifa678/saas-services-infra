variable "name_prefix" {
  description = "Canonical `<project>-<env>` prefix, from the guardrails module."
  type        = string
}

variable "vpc_id" {
  description = "VPC that hosts the Verified Access endpoint ENIs."
  type        = string
}

variable "endpoint_subnet_ids" {
  description = <<-EOT
    Subnets in which AVA places the endpoint ENIs. These must be able to route to
    `eks_api_cidr`. Supplying fewer than two subnets makes the endpoint a single-AZ
    SPOF, which the module rejects.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.endpoint_subnet_ids) >= 2
    error_message = "endpoint_subnet_ids must contain at least two subnets in distinct AZs."
  }
}

variable "eks_api_cidr" {
  description = <<-EOT
    CIDR the endpoint forwards to -- the supernet covering the subnets holding the
    private EKS API ENIs. A `cidr` endpoint routes to an address range, so this must
    actually contain the API ENIs or the endpoint resolves but never connects.
  EOT
  type        = string

  validation {
    condition     = can(cidrhost(var.eks_api_cidr, 0))
    error_message = "eks_api_cidr must be a valid CIDR block."
  }
}

variable "cidr_endpoints_custom_subdomain" {
  description = "Public subdomain AVA serves cidr endpoints under. Required for cidr endpoints."
  type        = string
}

variable "oidc_issuer" {
  description = "OIDC issuer URL of the trust provider (e.g. https://tenant.eu.auth0.com)."
  type        = string

  validation {
    condition     = startswith(var.oidc_issuer, "https://")
    error_message = "oidc_issuer must be an https:// URL."
  }
}

variable "oidc_client_id" {
  description = "OIDC client id for the AVA trust provider."
  type        = string
}

variable "oidc_client_secret" {
  description = "OIDC client secret. Prefer sourcing this from Secrets Manager in the calling layer."
  type        = string
  sensitive   = true
}

variable "oidc_scope" {
  description = "Scopes requested from the OIDC provider."
  type        = string
  default     = "openid profile email"
}

variable "oidc_endpoint_overrides" {
  description = "Override the derived Auth0 authorize/token/userinfo endpoints for a non-Auth0 provider."
  type = object({
    authorization_endpoint = optional(string)
    token_endpoint         = optional(string)
    user_info_endpoint     = optional(string)
  })
  default = {}
}

variable "policy_document" {
  description = <<-EOT
    Cedar policy evaluated for every request reaching the EKS API group. There is
    deliberately no default: `permit(principal, action, resource) when { true };`
    authenticates the user and then authorises everyone, which is not zero trust.
  EOT
  type        = string

  validation {
    condition     = !can(regex("when\\s*\\{\\s*true\\s*\\}", var.policy_document))
    error_message = "policy_document must not be an unconditional `when { true }` permit -- constrain it on a trust-provider claim."
  }
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key used for AVA server-side encryption and log encryption."
  type        = string
}

variable "logging_enabled" {
  description = "Emit AVA access logs to CloudWatch."
  type        = bool
  default     = true
}

variable "log_include_trust_context" {
  description = "Include the resolved trust context (OIDC claims) in access logs."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention for the AVA access log group."
  type        = number
  default     = 90
}

variable "fips_enabled" {
  description = "Enable FIPS-validated endpoints on the AVA instance."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
