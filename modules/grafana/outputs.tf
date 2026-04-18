output "grafana_workspace_endpoint" {
  value = aws_grafana_workspace.this.endpoint
}

output "grafana_workspace_id" {
  value = aws_grafana_workspace.this.id
}

output "prometheus_workspace_endpoint" {
  value = aws_prometheus_workspace.this.prometheus_endpoint
}

output "otel_collector_irsa_role_arn" {
  value = aws_iam_role.otel_collector_irsa.arn
}
