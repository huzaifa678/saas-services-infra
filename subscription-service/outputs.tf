output "secret_arn" {
  value = aws_secretsmanager_secret.subscription_service.arn
}
