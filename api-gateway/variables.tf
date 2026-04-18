variable "region" {
  type    = string
  default = "us-east-1"
}

variable "gateway_jwt_secret" {
  type      = string
  sensitive = true
}

variable "keycloak_jwks_url" {
  type    = string
  default = "http://keycloak:8081/realms/saas/protocol/openid-connect/certs"
}
