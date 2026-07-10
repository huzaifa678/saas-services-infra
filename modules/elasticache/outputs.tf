output "primary_endpoint" {
  description = "Primary endpoint address of the replication group."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = 6379
}

output "auth_token_secret_arn" {
  description = "Secrets Manager ARN holding the Redis AUTH token, or null when auth is disabled."
  value       = var.auth_token_enabled ? aws_secretsmanager_secret.auth_token[0].arn : null
}
