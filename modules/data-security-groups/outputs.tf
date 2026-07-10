output "rds_sg_id" {
  description = "Security group ID for RDS PostgreSQL instances."
  value       = aws_security_group.this["rds"].id
}

output "redis_sg_id" {
  description = "Security group ID for ElastiCache Redis."
  value       = aws_security_group.this["redis"].id
}

output "msk_sg_id" {
  description = "Security group ID for MSK Kafka brokers."
  value       = aws_security_group.this["msk"].id
}

output "opensearch_sg_id" {
  description = "Security group ID for the OpenSearch domain."
  value       = aws_security_group.this["opensearch"].id
}

output "msk_open_ports" {
  description = "Broker ports actually opened, derived from the enabled auth mechanisms."
  value       = sort([for p in local.msk_ports : tonumber(p)])
}
