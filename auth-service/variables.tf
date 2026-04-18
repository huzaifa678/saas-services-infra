variable "region" {
  type    = string
  default = "us-east-1"
}

variable "auth_jwt_secret" {
  type      = string
  sensitive = true
}

variable "auth_jwt_refresh_secret" {
  type      = string
  sensitive = true
}
