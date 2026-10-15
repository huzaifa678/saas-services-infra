output "grafana_endpoint" { value = module.observability.grafana_endpoint }
output "prometheus_endpoint" { value = module.observability.prometheus_endpoint }
output "opensearch_endpoint" { value = module.observability.opensearch_endpoint }
output "opensearch_dashboard_endpoint" { value = module.observability.opensearch_dashboard_endpoint }

output "otel_collector_role_arn" {
  description = "OTel collector role (bound to monitoring/otel-collector via Pod Identity in this layer)."
  value       = module.observability.otel_collector_role_arn
}

# ─── GitOps contract (observability half) ────────────────────────────────────
# The AMP / OpenSearch endpoints are born in this layer, after 20-data publishes
# the main gitops_contract. This second, additive contract is published to SSM
# /saas/<env>/gitops-contract-observability and consumed by the CD repo's
# scripts/render_gitops.py (--obs-contract) to render the OTel collector's
# values-<env>.generated.yaml. CD-facing env name mirrors the main contract
# (infra "test" tier -> "staging").
output "gitops_contract_observability" {
  description = "Observability half of the Infra -> GitOps contract (endpoints created in this layer)."
  value = {
    version     = 1
    environment = var.environment == "test" ? "staging" : var.environment
    observability = {
      stack               = var.observability[0]
      region              = var.region
      prometheus_endpoint = module.observability.prometheus_endpoint
      opensearch_endpoint = module.observability.opensearch_endpoint
      collector = {
        namespace       = "monitoring"
        service_account = "otel-collector"
      }
    }
  }
}
