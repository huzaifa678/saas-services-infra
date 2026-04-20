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

variable "enable_public_access" {
  type        = bool
  description = "allow cluster on the internet"
  default     = false
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

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for EKS secret encryption"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block for scoped egress rules"
}

variable "enable_verified_access" {
  type        = bool
  description = "Create AWS Verified Access endpoint in front of the private EKS API (prod only)"
  default     = false
}

variable "ava_oidc_issuer" {
  type        = string
  description = "Keycloak OIDC issuer URL for Verified Access trust provider"
  default     = "oidc-url"
}

variable "ava_oidc_client_id" {
  type        = string
  description = "Keycloak OIDC client ID for Verified Access"
  default     = ""
}

variable "ava_oidc_client_secret" {
  type        = string
  sensitive   = true
  description = "Keycloak OIDC client secret for Verified Access"
  default     = ""
}

variable "ava_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the Verified Access endpoint ENIs"
  default     = []
}
