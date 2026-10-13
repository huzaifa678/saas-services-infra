locals {
  env = var.environment == "test" ? "staging" : var.environment

  # Per-stack cluster labels the observability ApplicationSet selects on. A single
  # mutually-exclusive label could not express a cluster (e.g. prod) running both.
  stack_grafana = contains(var.observability, "grafana")
  stack_elk     = contains(var.observability, "elk")
}