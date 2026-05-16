output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_ca" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "eks_node_group" {
  value = aws_eks_node_group.eks_node_group
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer" {
  value = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "verified_access_endpoint_dns" {
  description = "DNS name of the Verified Access endpoint — use this as your kubectl server"
  value       = var.enable_verified_access ? aws_verifiedaccess_endpoint.eks_api[0].endpoint_domain : null
}

output "verified_access_endpoint_id" {
  value = var.enable_verified_access ? aws_verifiedaccess_endpoint.eks_api[0].id : null
}
