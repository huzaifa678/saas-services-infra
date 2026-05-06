variable "region" {
  type    = string
  default = "us-east-1"
}

variable "root_state_key" {
  type        = string
  description = "S3 key of the root Terraform state for this environment"
}


variable "stripe_api_key" {
  type      = string
  sensitive = true
}
