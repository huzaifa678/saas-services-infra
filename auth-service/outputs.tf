output "secret_arn" {
  value = aws_secretsmanager_secret.auth_service.arn
}
