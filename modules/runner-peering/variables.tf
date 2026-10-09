variable "name" {
  description = "Name prefix, e.g. saas-test."
  type        = string
}

# ── Runner side (requester) ──────────────────────────────────────────────────
variable "runner_vpc_id" {
  type = string
}

variable "runner_vpc_cidr" {
  type = string
}

variable "runner_route_table_id" {
  description = "The runner VPC's private route table (gets the route to the app CIDR)."
  type        = string
}

# ── Application side (accepter) ──────────────────────────────────────────────
variable "app_vpc_id" {
  type = string
}

variable "app_vpc_cidr" {
  type = string
}

variable "app_route_table_ids" {
  description = "The application VPC's private route tables (get the return route to the runner)."
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group; a 443 ingress from the runner CIDR is added to it."
  type        = string
}

# ── Private DNS ──────────────────────────────────────────────────────────────
variable "associate_eks_private_zone" {
  description = "Associate the EKS private hosted zone with the runner VPC so the API FQDN resolves. Disable to manage DNS out-of-band."
  type        = bool
  default     = true
}

variable "cluster_endpoint" {
  description = "EKS API endpoint; the private hosted zone name is derived from it unless eks_private_zone_name is set."
  type        = string
}

variable "eks_private_zone_name" {
  description = "Override for the EKS private hosted zone name (no scheme, no trailing slash). Empty = derive from cluster_endpoint."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
