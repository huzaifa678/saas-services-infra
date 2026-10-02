output "repository_url" {
  description = "Registry/repo URL the runner pulls the toolchain image from."
  value       = aws_ecr_repository.runner.repository_url
}

output "repository_arn" {
  description = "Repository ARN, for scoping the runner's ecr:*Layer* pull policy."
  value       = aws_ecr_repository.runner.arn
}

output "repository_name" {
  value = aws_ecr_repository.runner.name
}
