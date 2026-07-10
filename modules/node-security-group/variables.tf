variable "cluster_name" {
  description = "EKS cluster name. Also the karpenter.sh/discovery tag value."
  type        = string
}

variable "vpc_id" {
  description = "VPC hosting the worker nodes."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, used to scope intra-VPC egress."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
