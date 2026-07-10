output "vpc_id" { value = module.vpc.vpc_id }
output "vpc_cidr" { value = var.vpc_cidr }
output "public_subnets" { value = module.vpc.public_subnets }
output "private_subnets" { value = module.vpc.private_subnets }
output "azs" { value = local.azs }

output "nat_public_ips" {
  description = "Stable egress IPs. Allow-list these with third-party providers."
  value       = module.vpc.nat_public_ips
}

output "kms_key_arn" {
  description = "Shared customer-managed key. Encrypts EKS secrets, RDS, MSK, Redis, ECR and logs."
  value       = aws_kms_key.main.arn
}

output "cluster_name" {
  description = "Physical name prefix shared by every layer."
  value       = var.cluster_name
}

output "name_prefix" {
  description = "Guardrails <project>-<env> prefix, for tagging and logical names."
  value       = module.guardrails.name_prefix
}

output "ecr_repository_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "schema_registry_arn" { value = aws_glue_registry.schema_registry.arn }

output "vpc_flow_log_group_arn" { value = aws_cloudwatch_log_group.vpc_flow_logs.arn }
