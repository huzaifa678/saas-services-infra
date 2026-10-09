output "peering_connection_id" {
  value = aws_vpc_peering_connection.this.id
}

output "eks_private_zone_id" {
  description = "The EKS private hosted zone associated with the runner VPC, when enabled."
  value       = var.associate_eks_private_zone ? data.aws_route53_zone.eks_private[0].zone_id : null
}
