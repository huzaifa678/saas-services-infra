variable "domain_name" {
  type    = string
  default = "saas-opensearch"
}

variable "instance_type" {
  type    = string
  default = "t3.small.search"
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "volume_size" {
  type    = number
  default = 20
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "opensearch_sg_id" {
  type = string
}

variable "master_user_name" {
  type      = string
  default   = "admin"
  sensitive = true
}

variable "master_user_password" {
  type      = string
  sensitive = true
}
