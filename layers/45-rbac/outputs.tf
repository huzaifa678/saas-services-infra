output "deployer_group" {
  description = "The Kubernetes group the ci-deployer RBAC authorizes."
  value       = var.deployer_group
}

output "cluster_bootstrap_access_entry_arn" {
  description = "ARN of the gated cluster-admin access entry, when created."
  value       = try(aws_eks_access_entry.cluster_bootstrap[0].access_entry_arn, null)
}
