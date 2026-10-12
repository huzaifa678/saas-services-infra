variable "name" {
  description = "Name prefix for the runner resources, e.g. saas-prod."
  type        = string
}

variable "vpc_id" {
  description = "VPC the runner lives in (must have an egress path to GitHub, STS, ECR and the EKS API)."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the runner ASG."
  type        = list(string)
}

variable "github_owner" {
  description = "GitHub org/user that owns the infra repo."
  type        = string
}

variable "github_repo" {
  description = "Infra repository the runner registers against."
  type        = string
}

# ── GitHub App (runner registration) ─────────────────────────────────────────
# The runner authenticates as a GitHub App installation, not a user PAT: at boot
# it signs a short-lived JWT with the App private key, exchanges it for an
# installation token, then mints a runner registration token. App id and
# installation id are not secret (passed as vars); only the private key is a
# secret, seeded once out-of-band into the Secrets Manager secret this module
# creates. Benefits over a PAT: repo-scoped `administration` permission only, no
# user-expiry, and not tied to a human account.
variable "github_app_id" {
  description = "ID of the SAAS-infra-bot GitHub App used for runner registration."
  type        = string
}

variable "github_app_installation_id" {
  description = "Installation ID of the SAAS-infra-bot GitHub App on the infra repo/org."
  type        = string
}

variable "runner_labels" {
  description = "Labels the runner registers with; workflows target them via runs-on."
  type        = string
  default     = "self-hosted,vpc"
}

variable "instance_type" {
  description = "EC2 instance type for the runner."
  type        = string
  default     = "t3.medium"
}

variable "runner_version" {
  description = "Pinned actions-runner release. Must be >= GitHub's enforced minimum (2.329.0 as of 2026-02) or config.sh is rejected at registration."
  type        = string
  default     = "2.338.0"
}

variable "ecr_repository_arn" {
  description = "ARN of the toolchain ECR repo the host may pull (scopes the pull policy)."
  type        = string
}

variable "ecr_registry" {
  description = "Registry host (account.dkr.ecr.region.amazonaws.com) the host logs Docker into at boot."
  type        = string
}

variable "kms_key_arn" {
  description = "CMK for the App private-key secret and the root EBS volume. Empty uses AWS-managed keys."
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB); sized for Docker layer + toolchain image cache."
  type        = number
  default     = 30
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window for the App private-key secret."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
