output "cluster_name" { value = module.eks.eks_cluster_name }
output "cluster_endpoint" { value = module.eks.eks_cluster_endpoint }

output "cluster_ca" {
  value     = module.eks.eks_cluster_ca
  sensitive = true
}

output "eks_node_group" { value = module.eks.eks_node_group }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }
output "oidc_issuer" { value = module.eks.oidc_issuer }

output "eks_nodes_sg_id" {
  description = "Node security group. The sole permitted ingress source for the data tier."
  value       = module.node_security_group.security_group_id
}

output "karpenter_interruption_queue_name" { value = module.iam.karpenter_interruption_queue_name }
output "karpenter_node_role_arn" { value = module.iam.karpenter_node_role_arn }
