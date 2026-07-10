output "grafana_endpoint" { value = module.observability.grafana_endpoint }
output "prometheus_endpoint" { value = module.observability.prometheus_endpoint }
output "opensearch_endpoint" { value = module.observability.opensearch_endpoint }
output "opensearch_dashboard_endpoint" { value = module.observability.opensearch_dashboard_endpoint }

output "otel_collector_irsa_role_arn" {
  description = "Consumed by 50-addons-helm, which owns the collector's Kubernetes resources."
  value       = module.observability.otel_collector_irsa_role_arn
}
