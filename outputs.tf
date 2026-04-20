output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.eks_cluster_endpoint
}

output "auth_db" {
  sensitive = true
  value = var.auth_provider == "auth-service" ? {
    endpoint = module.rds_auth[0].endpoint
    db_name  = module.rds_auth[0].db_name
    username = module.rds_auth[0].username
  } : null
}

output "keycloak_db" {
  sensitive = true
  value = var.auth_provider == "keycloak" ? {
    endpoint = module.rds_keycloak[0].endpoint
    db_name  = module.rds_keycloak[0].db_name
    username = module.rds_keycloak[0].username
  } : null
}

output "subscription_db" {
  sensitive = true
  value = {
    endpoint = module.rds_subscription.endpoint
    db_name  = module.rds_subscription.db_name
    username = module.rds_subscription.username
  }
}

output "billing_db" {
  sensitive = true
  value = {
    endpoint = module.rds_billing.endpoint
    db_name  = module.rds_billing.db_name
    username = module.rds_billing.username
  }
}

output "usage_db" {
  sensitive = true
  value = {
    endpoint = module.rds_usage.endpoint
    db_name  = module.rds_usage.db_name
    username = module.rds_usage.username
  }
}

output "redis_endpoint" {
  value = module.elasticache.primary_endpoint
}

output "kafka_bootstrap_brokers" {
  value = module.kafka.bootstrap_brokers
}

output "schema_registry_arn" {
  value = aws_glue_registry.schema_registry.arn
}

output "grafana_endpoint" {
  value = try(module.grafana[0].grafana_workspace_endpoint, null)
}

output "prometheus_endpoint" {
  value = try(module.grafana[0].prometheus_workspace_endpoint, null)
}

output "opensearch_endpoint" {
  value = try(module.elk[0].opensearch_endpoint, null)
}

output "opensearch_dashboard_endpoint" {
  value = try(module.elk[0].opensearch_dashboard_endpoint, null)
}

# ─── ECR ─────────────────────────────────────────────────────────────────────
output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
