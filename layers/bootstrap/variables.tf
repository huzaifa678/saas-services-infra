variable "project" {
  description = "Project slug. Drives the name prefix."
  type        = string
  default     = "saas"
}

variable "environment" {
  description = "dev | test | prod. Selects the per-env bootstrap state and resources."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

# ── GitHub / OIDC ────────────────────────────────────────────────────────────
variable "github_owner" {
  description = "GitHub org/user that owns this infra repo."
  type        = string
  default     = "huzaifa678"
}

variable "github_repo" {
  description = "Infra repository name."
  type        = string
  default     = "saas-services-infra"
}

variable "default_branch" {
  description = "Branch whose pushes may assume the apply role."
  type        = string
  default     = "main"
}

variable "apply_environments" {
  description = "GitHub Environments whose deployments may assume the apply role. Defaults to this env."
  type        = list(string)
  default     = []
}

variable "bootstrap_environment" {
  description = "Protected GitHub Environment (required reviewers) that is the sole subject allowed to assume the gated cluster-bootstrap role. Empty defaults to the environment name."
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider in this account. Set false in the second+ env of a shared account and pass oidc_provider_arn."
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when create_oidc_provider is false."
  type        = string
  default     = ""
}

variable "state_bucket" {
  description = "Terraform state S3 bucket (matches root.hcl). Scopes the plan/apply roles to this env's state prefix."
  type        = string
  default     = "saas-state-bucket-399849"
}

variable "apply_managed_policy" {
  description = "AWS-managed policy attached to the apply and cluster-bootstrap roles."
  type        = string
  default     = "PowerUserAccess"
}

# NOTE: the self-hosted runner (and its VPC) moved to the separate `runner`
# layer (modules/runner-vpc + modules/gha-runner + modules/runner-peering).
# The cluster-facing knobs (deployer_group, manage_ci_deployer_rbac,
# create_gated_admin_access_entry, map_deployer_access_entry) moved to 45-rbac.
