variable "name" {
  description = "Name prefix for the OIDC roles, e.g. saas-prod."
  type        = string
}

variable "environment" {
  description = "Environment slug; scopes the tf-state object policy to this env's state prefix."
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user that owns the infra repo."
  type        = string
}

variable "github_repo" {
  description = "Infra repository name (the OIDC `sub` is scoped to owner/repo)."
  type        = string
}

variable "default_branch" {
  description = "Branch whose pushes may assume the apply role."
  type        = string
  default     = "main"
}

variable "apply_environments" {
  description = "GitHub Environments whose deployments may assume the apply role."
  type        = list(string)
  default     = []
}

variable "bootstrap_environment" {
  description = "Protected GitHub Environment (required reviewers) that is the ONLY subject allowed to assume the gated cluster-bootstrap role."
  type        = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false when it already exists in the account and pass oidc_provider_arn instead."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN, used when create_oidc_provider is false."
  type        = string
  default     = ""
}

variable "state_bucket" {
  description = "Terraform state S3 bucket; scopes the plan/apply roles' S3 access to this env's state prefix."
  type        = string
}

variable "apply_managed_policy" {
  description = "AWS-managed policy name attached to the apply and cluster-bootstrap roles (AWS side)."
  type        = string
  default     = "PowerUserAccess"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
