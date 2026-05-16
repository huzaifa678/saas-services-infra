output "grafana_endpoint" {
  value = try(module.grafana[0].grafana_workspace_endpoint, null)
}

output "prometheus_endpoint" {
  value = local.prometheus_endpoint
}

output "opensearch_endpoint" {
  value = try(module.elk[0].opensearch_endpoint, null)
}

output "opensearch_dashboard_endpoint" {
  value = try(module.elk[0].opensearch_dashboard_endpoint, null)
}
