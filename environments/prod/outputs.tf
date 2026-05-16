output "eks_cluster_name" {
  value = module.root.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.root.eks_cluster_endpoint
}

output "redis_endpoint" {
  value = module.root.redis_endpoint
}

output "msk_bootstrap_brokers" {
  value = module.root.msk_bootstrap_brokers
}

output "grafana_endpoint" {
  value = module.root.grafana_endpoint
}

output "prometheus_endpoint" {
  value = module.root.prometheus_endpoint
}

output "opensearch_endpoint" {
  value = module.root.opensearch_endpoint
}

output "opensearch_dashboard_endpoint" {
  value = module.root.opensearch_dashboard_endpoint
}

output "ecr_repository_urls" {
  value = module.root.ecr_repository_urls
}
