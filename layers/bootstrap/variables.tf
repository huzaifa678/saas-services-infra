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

variable "vpc_id" {
  description = "VPC the runner runs in."
  type        = string
}

variable "private_subnets" {
  description = "Private subnets for the runner ASG."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "Shared CMK; encrypts the toolchain ECR repo, the PAT secret and the runner root volume."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS API endpoint (private in test/prod)."
  type        = string
}

variable "cluster_ca" {
  description = "Base64 cluster CA certificate."
  type        = string
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

variable "runner_instance_type" {
  description = "EC2 instance type for the self-hosted runner."
  type        = string
  default     = "t3.medium"
}

variable "runner_labels" {
  description = "Labels the runner registers with; workflows target them via runs-on."
  type        = string
  default     = "self-hosted,vpc"
}

variable "runner_version" {
  description = "Pinned actions-runner release."
  type        = string
  default     = "2.328.0"
}

variable "deployer_group" {
  description = "Kubernetes group the ci-deployer RBAC binds and the tf-apply access entry maps to."
  type        = string
  default     = "saas:ci-deployers"
}

variable "manage_ci_deployer_rbac" {
  description = "Apply the ci-deployer RBAC. Requires the caller to be a cluster-admin on first apply."
  type        = bool
  default     = true
}

variable "create_gated_admin_access_entry" {
  description = "Grant the gated cluster-bootstrap role a cluster-admin EKS access entry."
  type        = bool
  default     = true
}

variable "map_deployer_access_entry" {
  description = "Create the STANDARD access entry mapping the tf-apply role to the ci-deployers group. Leave false until the steady-state deploy role has fully migrated to this role."
  type        = bool
  default     = true
}
