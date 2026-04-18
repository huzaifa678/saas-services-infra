output "opensearch_endpoint" {
  value = aws_opensearch_domain.this.endpoint
}

output "opensearch_dashboard_endpoint" {
  value = aws_opensearch_domain.this.dashboard_endpoint
}

output "domain_arn" {
  value = aws_opensearch_domain.this.arn
}
