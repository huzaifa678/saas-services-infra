module "grafana" {
  count  = var.stack == "grafana" ? 1 : 0
  source = "../grafana"

  workspace_name    = var.grafana_workspace_name
  oidc_provider_arn = var.oidc_provider_arn
  oidc_issuer       = var.oidc_issuer
}

module "elk" {
  count  = var.stack == "elk" ? 1 : 0
  source = "../elk"

  domain_name          = var.elk_domain_name
  subnet_ids           = var.subnet_ids
  opensearch_sg_id     = var.opensearch_sg_id
  master_user_name     = var.opensearch_master_username
  master_user_password = var.opensearch_master_password
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_issuer          = var.oidc_issuer
}

locals {
  prometheus_endpoint = var.stack == "grafana" ? (
    try(module.grafana[0].prometheus_workspace_endpoint, null)
  ) : try(module.elk[0].prometheus_workspace_endpoint, null)

  otel_irsa_role_arn = try(
    module.elk[0].otel_collector_irsa_role_arn,
    try(module.grafana[0].otel_collector_irsa_role_arn, null)
  )
}

module "otel" {
  source = "../otel"

  cluster_name                 = var.cluster_name
  otel_collector_irsa_role_arn = local.otel_irsa_role_arn
  prometheus_endpoint          = local.prometheus_endpoint
  opensearch_endpoint          = try(module.elk[0].opensearch_endpoint, null)
  opensearch_username          = var.opensearch_master_username
  opensearch_password          = var.opensearch_master_password
  region                       = var.region
  observability                = var.stack
}
