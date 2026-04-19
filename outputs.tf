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
    password = module.rds_auth[0].password
  } : null
}

output "keycloak_db" {
  sensitive = true
  value = var.auth_provider == "keycloak" ? {
    endpoint = module.rds_keycloak[0].endpoint
    db_name  = module.rds_keycloak[0].db_name
    username = module.rds_keycloak[0].username
    password = module.rds_keycloak[0].password
  } : null
}

output "subscription_db" {
  sensitive = true
  value = {
    endpoint = module.rds_subscription.endpoint
    db_name  = module.rds_subscription.db_name
    username = module.rds_subscription.username
    password = module.rds_subscription.password
  }
}

output "billing_db" {
  sensitive = true
  value = {
    endpoint = module.rds_billing.endpoint
    db_name  = module.rds_billing.db_name
    username = module.rds_billing.username
    password = module.rds_billing.password
  }
}

output "usage_db" {
  sensitive = true
  value = {
    endpoint = module.rds_usage.endpoint
    db_name  = module.rds_usage.db_name
    username = module.rds_usage.username
    password = module.rds_usage.password
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
  value = module.grafana.grafana_workspace_endpoint
}

output "prometheus_endpoint" {
  value = module.grafana.prometheus_workspace_endpoint
}

output "opensearch_endpoint" {
  value = module.elk.opensearch_endpoint
}

output "opensearch_dashboard_endpoint" {
  value = module.elk.opensearch_dashboard_endpoint
}

# ─── ECR ─────────────────────────────────────────────────────────────────────
output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
