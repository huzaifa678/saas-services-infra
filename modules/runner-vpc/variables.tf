variable "name" {
  description = "Name prefix, e.g. saas-test."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the runner VPC. MUST NOT overlap the application VPC it peers with (00-network uses 10.0.0.0/16)."
  type        = string
  default     = "10.100.0.0/16"
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
