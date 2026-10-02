output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN (created or passed through)."
  value       = local.provider_arn
}

output "tf_plan_role_arn" {
  value = aws_iam_role.tf_plan.arn
}

output "tf_apply_role_arn" {
  description = "Steady-state deployer role. Mapped to the ci-deployers K8s group, never cluster-admin."
  value       = aws_iam_role.tf_apply.arn
}

output "cluster_bootstrap_role_arn" {
  description = "Gated break-glass role; the sole principal granted a cluster-admin access entry."
  value       = aws_iam_role.cluster_bootstrap.arn
}
