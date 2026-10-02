variable "manifest_path" {
  description = "Absolute path to the ci-deployer RBAC manifest template (multi-document YAML)."
  type        = string
}

variable "deployer_group" {
  description = "Kubernetes group the RBAC binds; the steady-state deployer's EKS access entry maps its role to this group."
  type        = string
  default     = "saas:ci-deployers"
}
