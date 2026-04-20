data "aws_secretsmanager_secret_version" "subscription_db" {
  secret_id = local.common.subscription_db_secret_arn
}

resource "aws_secretsmanager_secret" "subscription_service" {
  name                    = "saas/subscription-service"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "subscription_service" {
  secret_id = aws_secretsmanager_secret.subscription_service.id
  secret_string = jsonencode({
    POSTGRES_HOST       = split(":", local.db.endpoint)[0]
    POSTGRES_PORT       = "5432"
    POSTGRES_USER       = local.db.username
    POSTGRES_PASSWORD   = local.db.password
    POSTGRES_DB         = local.db.db_name
    KAFKA_BROKER          = local.common.kafka_bootstrap_brokers
    SCHEMA_REGISTRY_ARN   = local.common.schema_registry_arn
  })
}
