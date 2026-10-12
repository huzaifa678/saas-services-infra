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
variable "enable_peering_dns_resolution" {
  description = "Enable cross-VPC DNS resolution over the peering so the runner VPC resolves the app VPC's private EKS API endpoint. Disable to manage DNS out-of-band."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
