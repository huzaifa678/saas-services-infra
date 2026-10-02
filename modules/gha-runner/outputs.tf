output "runner_role_arn" {
  description = "Instance role ARN. Deliberately holds no deploy or cluster rights."
  value       = aws_iam_role.runner.arn
}

output "pat_secret_arn" {
  description = "Secrets Manager ARN to seed the GitHub registration PAT into (out-of-band)."
  value       = aws_secretsmanager_secret.runner_pat.arn
}

output "security_group_id" {
  value = aws_security_group.runner.id
}

output "asg_name" {
  description = "Runner ASG name, for cycling the instance after seeding the PAT."
  value       = aws_autoscaling_group.runner.name
}
