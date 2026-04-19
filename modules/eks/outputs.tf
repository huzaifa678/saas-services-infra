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

output "ssm_sg_id" {
  value = var.enable_ssm_access ? aws_security_group.ssm_endpoints_sg[0].id : null
}
