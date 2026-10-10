variable "project" {
  description = "Project slug. Drives tags and the guardrails name prefix."
  type        = string
  default     = "saas"
}

variable "environment" {
  description = "dev | test | prod. Selects the security posture via guardrails."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "services" {
  description = "Microservice image names — one ECR repository is created per entry."
  type        = list(string)
  default = [
    "api-gateway",
    "auth-service",
    "subscription-service",
    "billing-service",
    "usage-service",
    "agent-service",
    "backstage-saas"
  ]
}

variable "functions" {
  description = <<-EOT
    Crossplane composition function package names — one ECR repository is created
    per entry, with the same posture as the service repos. The build-function
    workflow (CD repo) pushes both the runtime image (runtime-<sha> tag) and the
    xpkg package (<sha> tag) to <registry>/<function>, so each name here must match
    the function directory name the workflow builds.
  EOT
  type        = list(string)
  default = [
    "function-appdatabase",
    "function-appcache",
  ]
}

variable "capacity_tier" {
  description = "Named capacity/scale tier (cost only). Passed through to guardrails; null => the env default."
  type        = string
  default     = null
}

variable "sizing" {
  description = "Per-environment sizing overrides. Cost/capacity only. Unused here; accepted for the shared guardrails contract."
  type        = any
  default     = {}
}

variable "allowed_public_access_cidrs" {
  description = "Passed through to guardrails for the shared security contract."
  type        = list(string)
  default     = []
}

variable "auth_provider" {
  description = "keycloak | auth-service. Passed through to guardrails."
  type        = string
  default     = "keycloak"
}

variable "observability" {
  description = "Subset of [elk, grafana]. Passed through to guardrails."
  type        = list(string)
  default     = ["elk"]
}
