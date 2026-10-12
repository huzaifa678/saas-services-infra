output "peering_connection_id" {
  value = aws_vpc_peering_connection.this.id
}

output "peering_dns_resolution_enabled" {
  description = "Whether cross-VPC DNS resolution is enabled so the runner VPC resolves the private EKS API endpoint."
  value       = var.enable_peering_dns_resolution
}
