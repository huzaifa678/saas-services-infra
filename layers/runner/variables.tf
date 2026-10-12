variable "project" {
  description = "Project slug."
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

variable "runner_vpc_cidr" {
  description = "CIDR for the isolated runner VPC. Must not overlap the app VPC (10.0.0.0/16)."
  type        = string
  default     = "10.100.0.0/16"
}

variable "runner_instance_type" {
  description = "EC2 instance type for the self-hosted runner."
  type        = string
  default     = "t3.medium"
}

variable "github_owner" {
  description = "GitHub org/user that owns the infra repo."
  type        = string
  default     = "huzaifa678"
}

variable "github_repo" {
  description = "Infra repository name."
  type        = string
  default     = "saas-services-infra"
}

variable "github_app_id" {
  description = "ID of the SAAS-infra-bot GitHub App used for runner registration (not secret)."
  type        = string
}

variable "github_app_installation_id" {
  description = "Installation ID of the SAAS-infra-bot GitHub App on the infra repo (not secret)."
  type        = string
}

# ── From bootstrap ───────────────────────────────────────────────────────────
variable "ecr_repository_arn" {
  description = "Toolchain ECR repo ARN (bootstrap layer) the runner may pull."
  type        = string
}

variable "toolchain_repository_url" {
  description = "Toolchain ECR repo URL (bootstrap layer); the registry host is derived from it."
  type        = string
}

# ── From 00-network (peer VPC) ───────────────────────────────────────────────
variable "app_vpc_id" {
  type = string
}

variable "app_vpc_cidr" {
  type = string
}

variable "app_route_table_ids" {
  description = "Application VPC private route tables (return route to the runner)."
  type        = list(string)
}

# ── From 10-platform (cluster) ───────────────────────────────────────────────
variable "cluster_security_group_id" {
  description = "EKS cluster security group; a 443 ingress from the runner CIDR is added."
  type        = string
}

# ── Private DNS ──────────────────────────────────────────────────────────────
variable "enable_peering_dns_resolution" {
  description = "Enable cross-VPC DNS resolution over the peering so the runner VPC resolves the private EKS API endpoint. Disable to manage DNS out-of-band."
  type        = bool
  default     = true
}
