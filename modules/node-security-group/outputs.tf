output "security_group_id" {
  description = "Security group ID for EKS worker nodes."
  value       = aws_security_group.eks_nodes.id
}

output "security_group_name" {
  description = "Name of the EKS worker node security group."
  value       = aws_security_group.eks_nodes.name
}
