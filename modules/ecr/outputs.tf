output "repository_urls" {
  description = "Map of repository name => registry/repo URL services push to and pods pull from."
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repository name => ARN, for scoping pull/push IAM policies."
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}

output "repository_names" {
  description = "The repository names created."
  value       = sort(keys(aws_ecr_repository.this))
}
