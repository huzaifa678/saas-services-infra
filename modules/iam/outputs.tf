output "cert_manager_irsa_role_arn" {
  description = "ARN of the cert-manager IRSA role"
  value       = aws_iam_role.cert_manager_irsa.arn
}

output "external_dns_irsa_role_arn" {
  description = "ARN of the external-dns IRSA role"
  value       = aws_iam_role.external_dns_irsa.arn
}

output "aws_lb_controller_irsa_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = aws_iam_role.aws_lb_controller_irsa.arn
}

output "external_secrets_irsa_role_arn" {
  description = "ARN of the external-secrets IRSA role"
  value       = aws_iam_role.external_secrets_irsa.arn
}

output "karpenter_irsa_role_arn" {
  description = "ARN of the Karpenter controller IRSA role"
  value       = aws_iam_role.karpenter_irsa.arn
}

output "karpenter_node_role_arn" {
  description = "ARN of the Karpenter worker node instance role"
  value       = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Name of the Karpenter worker node instance profile"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  description = "Name of the SQS queue used by Karpenter interruption handlers"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "ebs_csi_role_arn" {
  description = "ARN of the EBS CSI driver Pod Identity role"
  value       = aws_iam_role.ebs_csi.arn
}

output "karpenter_interruption_queue_arn" {
  description = "ARN of the SQS queue used by Karpenter interruption handlers"
  value       = aws_sqs_queue.karpenter_interruption.arn
}
