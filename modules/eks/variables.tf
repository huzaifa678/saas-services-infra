variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.32"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "cluster_endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to access the EKS public endpoint"
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for EKS nodes"
  default     = "t3.medium"
}

variable "desired_size" {
  type    = number
  default = 3
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 5
}

variable "region" {
  type    = string
  default = "us-east-1"
}
