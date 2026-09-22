output "primary_endpoint" {
  description = "Connectable endpoint. The configuration endpoint in cluster mode (clients must be cluster-aware), otherwise the primary endpoint."
  value = local.cluster_mode_enabled ? (
    aws_elasticache_replication_group.this.configuration_endpoint_address
    ) : (
    aws_elasticache_replication_group.this.primary_endpoint_address
  )
}

output "configuration_endpoint" {
  description = "Cluster-mode configuration endpoint, or empty for a single-shard cluster."
  value       = aws_elasticache_replication_group.this.configuration_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint (single-shard cluster mode disabled only); empty in cluster mode."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = 6379
}

output "replication_group_id" {
  description = "Replication group identifier; the resource_id root for tenant users and auto scaling."
  value       = aws_elasticache_replication_group.this.replication_group_id
}

output "cluster_mode_enabled" {
  description = "Whether the cluster is running Redis Cluster mode (num_shards > 1)."
  value       = local.cluster_mode_enabled
}

output "user_group_id" {
  description = "Redis ACL user group ID that self-service tenant users join, or null when RBAC is disabled."
  value       = var.rbac_enabled ? aws_elasticache_user_group.this[0].user_group_id : null
}

output "auth_token_secret_arn" {
  description = "Secrets Manager ARN holding the Redis AUTH token, or null when auth is disabled or RBAC is in use."
  value       = local.auth_token_active ? aws_secretsmanager_secret.auth_token[0].arn : null
}
