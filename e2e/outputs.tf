output "e2e_secret_arn" {
  description = "ARN of the saas/e2e Secrets Manager secret (ESO source for the smoke runner)."
  value       = aws_secretsmanager_secret.e2e.arn
}
