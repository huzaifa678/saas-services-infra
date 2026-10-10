output "runner_role_arn" {
  description = "Instance role ARN. Deliberately holds no deploy or cluster rights."
  value       = aws_iam_role.runner.arn
}

output "app_key_secret_arn" {
  description = "Secrets Manager ARN to seed the GitHub App private key (PEM) into (out-of-band, once)."
  value       = aws_secretsmanager_secret.runner_app_key.arn
}

output "security_group_id" {
  value = aws_security_group.runner.id
}

output "asg_name" {
  description = "Runner ASG name, for cycling the instance after seeding the App key."
  value       = aws_autoscaling_group.runner.name
}
