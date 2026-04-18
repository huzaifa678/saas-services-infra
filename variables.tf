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

variable "cluster_endpoint_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
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

variable "auth_db_port" {
  type = string
  default = null
  sensitive = false
}

variable "subscription_db_port" {
  type = string
  default = null
  sensitive = false
}

variable "billing_db_port" {
  type = string
  default = null
  sensitive = false
}

variable "usage_db_port" {
  type = string
  default = null
  sensitive = false
}

variable "keycloak_db_port" {
  type = string
  default = null
  sensitive = false
}

variable "opensearch_master_password" {
  type      = string
  sensitive = true
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
