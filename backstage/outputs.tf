output "secret_arn" {
  description = "ARN of the composed backstage-app secret (consumed by the CD backstage-app ExternalSecret)."
  value       = aws_secretsmanager_secret.backstage_app.arn
}
