output "secret_arn" {
  value = aws_secretsmanager_secret.billing_service.arn
}
