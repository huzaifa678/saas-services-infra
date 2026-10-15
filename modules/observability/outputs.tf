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

output "otel_collector_role_arn" {
  description = <<-EOT
    Role the OTel collector assumes via EKS Pod Identity. The collector's
    Kubernetes resources live in the CD repo; this layer binds the role to the
    collector's namespace/ServiceAccount with an aws_eks_pod_identity_association.
  EOT
  value       = local.otel_collector_role_arn
}
