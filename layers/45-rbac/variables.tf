variable "project" {
  description = "Project slug. Drives tags."
  type        = string
  default     = "saas"
}

variable "environment" {
  description = "dev | test | prod."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

# ── From 10-platform (cluster handle for the kubectl provider) ───────────────
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

# ── From bootstrap (scoped CI role ARNs) ─────────────────────────────────────
variable "cluster_bootstrap_role_arn" {
  description = "ARN of the gated cluster-bootstrap role that gets the cluster-admin access entry."
  type        = string
}

variable "tf_apply_role_arn" {
  description = "ARN of the steady-state tf-apply role mapped to the ci-deployers group."
  type        = string
}

# ── RBAC knobs (individually toggleable to stage the migration) ──────────────
variable "deployer_group" {
  description = "Kubernetes group the ci-deployer RBAC binds and the tf-apply access entry maps to."
  type        = string
  default     = "saas:ci-deployers"
}

variable "manage_ci_deployer_rbac" {
  description = "Apply the ci-deployer RBAC. Requires the caller to be a cluster-admin (the gated cluster-bootstrap role or the human bootstrapper) on first apply."
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
