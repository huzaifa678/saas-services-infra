output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_ca" {
  value = module.eks.cluster_certificate_authority_data
}

output "eks_node_group" {
  description = "Managed node group object. Consumed as a depends_on handle so Helm installs wait for nodes."
  value       = module.eks.eks_managed_node_groups["default"]
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_issuer" {
  value = module.eks.cluster_oidc_issuer_url
}

output "cluster_admin_principal_arns" {
  description = "Principals granted cluster admin via access entries."
  value       = tolist(local.admin_principal_arns)
}
