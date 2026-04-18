variable "workspace_name" {
  type    = string
  default = "saas-grafana"
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN from EKS module"
}

variable "oidc_issuer" {
  type        = string
  description = "OIDC issuer URL from EKS module"
}
