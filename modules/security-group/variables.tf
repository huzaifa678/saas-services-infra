variable "cluster_name" {
  type        = string
  description = "EKS cluster name, used as name prefix"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for all security groups"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR used for intra-VPC egress rules"
}

variable "enable_verified_access" {
  type        = bool
  description = "Whether to create the Verified Access endpoint security group"
  default     = false
}

variable "ava_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the Verified Access endpoint ENIs"
  default     = []
}
