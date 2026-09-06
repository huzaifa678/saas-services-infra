data "aws_secretsmanager_secret_version" "subscription_db" {
  secret_id = var.subscription_db_secret_arn
}

resource "aws_secretsmanager_secret" "subscription_service" {
  name                    = "saas/subscription-service"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "subscription_service" {
  secret_id = aws_secretsmanager_secret.subscription_service.id
  secret_string = jsonencode({
    POSTGRES_HOST     = split(":", local.db.endpoint)[0]
    POSTGRES_PORT     = "5432"
    POSTGRES_USER     = local.db.username
    POSTGRES_PASSWORD = local.db.password
    POSTGRES_DB       = local.db.db_name
    KAFKA_BROKER      = var.kafka_bootstrap_brokers
    # MSK SASL/IAM: the pod authenticates with its Pod Identity role (module
    # msk_client_identity["subscription-service"] in 20-data). No secret material.
    KAFKA_SECURITY_PROTOCOL                  = "SASL_SSL"
    KAFKA_SASL_MECHANISM                     = "AWS_MSK_IAM"
    KAFKA_SASL_JAAS_CONFIG                   = "software.amazon.msk.auth.iam.IAMLoginModule required;"
    KAFKA_SASL_CLIENT_CALLBACK_HANDLER_CLASS = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
    SCHEMA_REGISTRY_ARN                      = var.schema_registry_arn
  })
}
