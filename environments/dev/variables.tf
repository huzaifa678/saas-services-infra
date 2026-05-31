variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.32"
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "enable_public_access" {
  type = bool
}

variable "enable_verified_access" {
  type    = bool
  default = false
}

variable "node_instance_type" {
  type = string
}

variable "desired_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "auth_provider" {
  type = string
}

variable "observability" {
  type = string
}

variable "auth_db_password" {
  type      = string
  sensitive = true
}

variable "subscription_db_password" {
  type      = string
  sensitive = true
}

variable "billing_db_password" {
  type      = string
  sensitive = true
}

variable "usage_db_password" {
  type      = string
  sensitive = true
}

variable "keycloak_db_password" {
  type      = string
  sensitive = true
}

variable "opensearch_master_username" {
  type = string
}

variable "opensearch_master_password" {
  type      = string
  sensitive = true
}

variable "openai_api_key" {
  type      = string
  sensitive = true
}
