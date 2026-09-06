locals {
  # CD-repo env label (selects values-<env>.yaml + post-renderer overlays/<env>).
  # Keyed on auth_provider so it is independent of the now multi-valued
  # observability list, and preserves the prior output for the all-elk clusters
  # (keycloak -> prod, auth-service -> staging).
  env = var.auth_provider == "keycloak" ? "prod" : "staging"

  # Per-stack cluster labels the observability ApplicationSet selects on. A single
  # mutually-exclusive label could not express a cluster (e.g. prod) running both.
  stack_grafana = contains(var.observability, "grafana")
  stack_elk     = contains(var.observability, "elk")
}