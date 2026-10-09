output "toolchain_repository_url" {
  description = "ECR repo the runner pulls the per-env toolchain image from."
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "Toolchain ECR repo ARN; the runner layer grants its instance role pull on this."
  value       = module.ecr.repository_arn
}

output "bootstrap_kms_key_arn" {
  description = "The dedicated CMK encrypting the toolchain ECR repo."
  value       = aws_kms_key.bootstrap.arn
}

output "gha_tf_plan_role_arn" {
  value = module.oidc.tf_plan_role_arn
}

output "gha_tf_apply_role_arn" {
  description = "Set repo secret AWS_DEPLOY_ROLE_ARN to this; it is the least-privilege ci-deployers identity."
  value       = module.oidc.tf_apply_role_arn
}

output "gha_cluster_bootstrap_role_arn" {
  description = "Set repo/Environment var AWS_ROLE_CLUSTER_BOOTSTRAP to this."
  value       = module.oidc.cluster_bootstrap_role_arn
}

output "github_oidc_provider_arn" {
  value = module.oidc.oidc_provider_arn
}
