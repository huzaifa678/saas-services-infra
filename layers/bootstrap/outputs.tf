output "toolchain_repository_url" {
  description = "ECR repo the runner pulls the per-env toolchain image from."
  value       = module.ecr.repository_url
}

output "runner_pat_secret_arn" {
  description = "Seed the GitHub registration PAT here (out-of-band), then cycle the ASG."
  value       = module.runner.pat_secret_arn
}

output "runner_asg_name" {
  value = module.runner.asg_name
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

output "deployer_group" {
  value = var.deployer_group
}
