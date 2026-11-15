resource "aws_secretsmanager_secret" "e2e" {
  name                    = "saas/e2e"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "e2e" {
  secret_id = aws_secretsmanager_secret.e2e.id
  secret_string = jsonencode({
    kafka_bootstrap = var.kafka_bootstrap_brokers
  })
}
