locals {
  ordered_public_subnets  = sort(var.public_subnets)
  ordered_private_subnets = sort(var.private_subnets)
}

locals {
  observability_map = {
    grafana = var.observability == "grafana" ? true : false
    elk     = var.observability == "elk" ? true : false
  }
  services = ["api-gateway", "auth-service", "subscription-service", "billing-service", "usage-service"]
}

locals {
  prometheus_endpoint = var.observability == "grafana" ? (
    try(module.grafana[0].prometheus_workspace_endpoint, null)
  ) : var.observability == "elk" ? (
    try(module.elk[0].prometheus_workspace_endpoint, null)
  ) : null
}