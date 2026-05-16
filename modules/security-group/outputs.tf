output "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "eks_nodes_security_group_name" {
  description = "Name of the EKS worker nodes security group"
  value       = aws_security_group.eks_nodes.name
}

output "rds_sg_id" {
  description = "Security group ID for RDS PostgreSQL instances"
  value       = aws_security_group.rds_sg.id
}

output "redis_sg_id" {
  description = "Security group ID for ElastiCache Redis"
  value       = aws_security_group.redis_sg.id
}

output "msk_sg_id" {
  description = "Security group ID for MSK Kafka brokers"
  value       = aws_security_group.msk_sg.id
}

output "opensearch_sg_id" {
  description = "Security group ID for OpenSearch domain"
  value       = aws_security_group.opensearch_sg.id
}

output "ava_endpoint_sg_id" {
  description = "Security group ID for the AWS Verified Access endpoint (null when Verified Access is disabled)"
  value       = var.enable_verified_access ? aws_security_group.ava_endpoint[0].id : null
}
