output "opensearch_endpoint" {
  value = aws_opensearch_domain.this.endpoint
}

output "opensearch_dashboard_endpoint" {
  value = aws_opensearch_domain.this.dashboard_endpoint
}

output "domain_arn" {
  value = aws_opensearch_domain.this.arn
}

output "prometheus_workspace_endpoint" {
  value = aws_prometheus_workspace.this.prometheus_endpoint
}

output "otel_collector_irsa_role_arn" {
  value = aws_iam_role.otel_collector_irsa.arn
}