variable "region" {
  type    = string
  default = "us-east-1"
}

variable "root_state_key" {
  type        = string
  description = "S3 key of the root Terraform state for this environment"
}


variable "gateway_jwt_secret" {
  type      = string
  sensitive = true
}

variable "keycloak_jwks_url" {
  type    = string
  default = "http://keycloak:8081/realms/saas/protocol/openid-connect/certs"
}
