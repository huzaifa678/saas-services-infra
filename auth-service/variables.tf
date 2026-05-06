variable "region" {
  type    = string
  default = "us-east-1"
}

variable "root_state_key" {
  type        = string
  description = "S3 key of the root Terraform state for this environment"
}


variable "auth_jwt_secret" {
  type      = string
  sensitive = true
}

variable "auth_jwt_refresh_secret" {
  type      = string
  sensitive = true
}
