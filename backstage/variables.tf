variable "region" {
  type    = string
  default = "us-east-1"
}

variable "keycloak_host" {
  type        = string
  description = "Public Keycloak hostname. The OIDC discovery (metadata) URL Backstage reads is derived from it."
  default     = "keycloak.freeeasycrypto.com"
}

variable "keycloak_realm" {
  type        = string
  description = "Keycloak realm that holds the backstage OIDC client."
  default     = "saas"
}

variable "keycloak_client_id" {
  type        = string
  description = "OIDC client id for the portal (matches the Keycloak client)."
  default     = "backstage"
}
