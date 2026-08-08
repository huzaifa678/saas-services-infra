variable "region" {
  type    = string
  default = "us-east-1"
}

variable "keycloak_jwks_url" {
  type    = string
  default = "http://keycloak:8081/realms/saas/protocol/openid-connect/certs"
}

variable "redis_endpoint" {
  type        = string
  description = "ElastiCache primary endpoint. From 20-data."
}
