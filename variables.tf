variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "saas-eks-cluster"
}

variable "kubernetes_version" {
  type    = string
  default = "1.32"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "enable_public_access" {
  type    = bool
  default = false
}

variable "enable_ssm_access" {
  type        = bool
  description = "Enable SSM VPC endpoints + IRSA for zero-VPN private EKS access (prod only)"
  default     = false
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
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

variable "auth_db_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "subscription_db_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "billing_db_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "usage_db_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "keycloak_db_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "opensearch_master_password" {
  type      = string
  sensitive = true
}

variable "opensearch_master_username" {
  type    = string
  default = "admin"
}

variable "openai_api_key" {
  type      = string
  sensitive = true
}

variable "auth_provider" {
  type        = string
  default     = "keycloak"
  description = "Which auth provider to deploy: 'keycloak' or 'auth-service'"

  validation {
    condition     = contains(["keycloak", "auth-service"], var.auth_provider)
    error_message = "auth_provider must be 'keycloak' or 'auth-service'."
  }
}

variable "observability" {
  type        = string
  default     = "elk"
  description = "Which observability stack to deploy: 'elk' or 'grafana'"

  validation {
    condition     = contains(["elk", "grafana"], var.observability)
    error_message = "observability must be 'elk' or 'grafana'."
  }
}
