data "aws_secretsmanager_secret_version" "usage_db" {
  secret_id = var.usage_db_secret_arn
}

data "aws_secretsmanager_secret_version" "llm" {
  secret_id = "saas/${var.environment}/llm-api-keys"
}

resource "aws_secretsmanager_secret" "usage_service" {
  name                    = "saas/usage-service"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "usage_service" {
  secret_id = aws_secretsmanager_secret.usage_service.id
  secret_string = jsonencode({
    DATABASE_URL = "postgresql+psycopg2://${local.db.username}:${local.db.password}@${local.db.endpoint}/${local.db.db_name}"

    KAFKA_BOOTSTRAP_SERVERS = var.kafka_bootstrap_brokers

    OPENAI_API_KEY = local.llm.OPENAI_API_KEY
  })
}
