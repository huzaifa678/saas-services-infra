output "databases" {
  description = "Connection metadata for every database this environment deploys."
  sensitive   = true
  value = {
    for k, m in module.rds : k => {
      endpoint = m.endpoint
      db_name  = m.db_name
      username = m.username
    }
  }
}

output "db_secret_arns" {
  description = "Secrets Manager ARNs holding each database's master credentials."
  value       = { for k, m in module.rds : k => m.secret_arn }
}

output "redis_endpoint" { value = module.elasticache.primary_endpoint }
output "redis_port" { value = module.elasticache.port }

output "redis_auth_secret_arn" {
  description = "Secrets Manager ARN holding the Redis AUTH token."
  value       = module.elasticache.auth_token_secret_arn
}

output "msk_bootstrap_brokers" { value = module.msk.bootstrap_brokers }
output "msk_cluster_arn" { value = module.msk.cluster_arn }

output "msk_open_ports" {
  description = "Broker ports opened, derived from the enabled SASL mechanisms."
  value       = module.data_security_groups.msk_open_ports
}

output "rds_sg_id" { value = module.data_security_groups.rds_sg_id }
output "redis_sg_id" { value = module.data_security_groups.redis_sg_id }
output "msk_sg_id" { value = module.data_security_groups.msk_sg_id }
output "opensearch_sg_id" { value = module.data_security_groups.opensearch_sg_id }

output "keycloak_db_endpoint" {
  description = "Keycloak database endpoint, or empty when auth_provider is not keycloak."
  value       = try(module.rds["keycloak"].endpoint, "")
}
