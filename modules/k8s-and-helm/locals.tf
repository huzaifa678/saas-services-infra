locals {
  env = var.observability == "elk" ? (
    var.auth_provider == "keycloak" ? "prod" : "staging"
  ) : "dev"
}