output "grafana_endpoint" {
  description = "Managed Grafana workspace endpoint, or null when stack = 'elk'."
  value       = try(module.grafana[0].grafana_workspace_endpoint, null)
}

output "prometheus_endpoint" {
  description = "Amazon Managed Prometheus workspace endpoint."
  value       = local.prometheus_endpoint
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint, or null when stack = 'grafana'."
  value       = try(module.elk[0].opensearch_endpoint, null)
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint, or null when stack = 'grafana'."
  value       = try(module.elk[0].opensearch_dashboard_endpoint, null)
}

output "otel_collector_irsa_role_arn" {
  description = <<-EOT
    Role the OTel collector assumes. Consumed by the 50-addons-helm layer, which
    owns the collector's Kubernetes resources.
  EOT
  value       = local.otel_irsa_role_arn
}
