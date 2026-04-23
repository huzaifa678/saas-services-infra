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

output "cert_manager_irsa_role_arn" {
  value = aws_iam_role.cert_manager_irsa.arn
}

output "external_dns_irsa_role_arn" {
  value = aws_iam_role.external_dns_irsa.arn
}

output "aws_lb_controller_irsa_role_arn" {
  value = aws_iam_role.aws_lb_controller_irsa.arn
}

output "external_secrets_irsa_role_arn" {
  value = aws_iam_role.external_secrets_irsa.arn
}

output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}

output "redis_sg_id" {
  value = aws_security_group.redis_sg.id
}

output "msk_sg_id" {
  value = aws_security_group.msk_sg.id
}

output "opensearch_sg_id" {
  value = aws_security_group.opensearch_sg.id
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

output "karpenter_irsa_role_arn" {
  value = aws_iam_role.karpenter_irsa.arn
}

output "karpenter_node_role_arn" {
  value = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_node_instance_profile_name" {
  value = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  value = aws_sqs_queue.karpenter_interruption.name
}
