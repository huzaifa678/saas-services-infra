locals {
  # elk = prod/staging, grafana = dev
  clusters_path = var.observability == "elk" ? (
    var.auth_provider == "keycloak" ? "manifests/base/overlays/prod" : "manifests/base/overlays/staging"
  ) : "manifests/base/overlays/dev"
}