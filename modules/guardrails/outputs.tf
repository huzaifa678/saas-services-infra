output "environment" {
  description = "The resolved environment name."
  value       = local.env
  depends_on  = [terraform_data.guardrail_invariants]
}

output "security" {
  description = "Resolved, non-overridable security posture for this environment."
  value       = local.security
  depends_on  = [terraform_data.guardrail_invariants]
}

output "sizing" {
  description = "Resolved sizing/capacity settings (defaults merged with caller overrides)."
  value       = local.sizing
  depends_on  = [terraform_data.guardrail_invariants]
}

output "name_prefix" {
  description = "Canonical `<project>-<env>` prefix for resource naming."
  value       = local.name_prefix
  depends_on  = [terraform_data.guardrail_invariants]
}

output "common_tags" {
  description = "Mandatory tag set applied to every taggable resource."
  value       = local.common_tags
  depends_on  = [terraform_data.guardrail_invariants]
}

output "is_production" {
  description = "Convenience flag for consumers that branch on prod-only behaviour."
  value       = local.env == "prod"
  depends_on  = [terraform_data.guardrail_invariants]
}

output "auth_provider" {
  description = "Auth provider selected for this environment."
  value       = var.auth_provider
  depends_on  = [terraform_data.guardrail_invariants]
}

output "observability" {
  description = "Observability stack selected for this environment."
  value       = var.observability
  depends_on  = [terraform_data.guardrail_invariants]
}
