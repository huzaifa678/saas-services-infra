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

variable "cluster_endpoint" {
  description = "EKS API endpoint; the private hosted zone name is derived from it."
  type        = string
}

# ── Private DNS ──────────────────────────────────────────────────────────────
variable "associate_eks_private_zone" {
  description = "Associate the EKS private hosted zone with the runner VPC so the API FQDN resolves over the peering."
  type        = bool
  default     = true
}

variable "eks_private_zone_name" {
  description = "Override for the EKS private hosted zone name. Empty = derive from cluster_endpoint."
  type        = string
  default     = ""
}
