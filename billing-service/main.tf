data "aws_secretsmanager_secret_version" "billing_db" {
  secret_id = var.billing_db_secret_arn
}

data "aws_secretsmanager_secret_version" "stripe" {
  secret_id = "saas/${var.environment}/stripe-api-key"
}

resource "aws_secretsmanager_secret" "billing_service" {
  name                    = "saas/billing-service"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "billing_service" {
  secret_id = aws_secretsmanager_secret.billing_service.id
  secret_string = jsonencode({
    SPRING_DATASOURCE_URL          = "jdbc:postgresql://${local.db.endpoint}/${local.db.db_name}"
    SPRING_DATASOURCE_USERNAME     = local.db.username
    SPRING_DATASOURCE_PASSWORD     = local.db.password
    SPRING_DATA_REDIS_HOST         = var.redis_endpoint
    SPRING_DATA_REDIS_PORT         = "6379"
    SPRING_KAFKA_BOOTSTRAP_SERVERS = var.kafka_bootstrap_brokers
    # MSK SASL/IAM: the pod authenticates with its Pod Identity role (module
    # msk_client_identity["billing-service"] in 20-data). No secret material —
    # the IAM callback handler signs the connection with the assumed role.
    SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL                  = "SASL_SSL"
    SPRING_KAFKA_PROPERTIES_SASL_MECHANISM                     = "AWS_MSK_IAM"
    SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG                   = "software.amazon.msk.auth.iam.IAMLoginModule required;"
    SPRING_KAFKA_PROPERTIES_SASL_CLIENT_CALLBACK_HANDLER_CLASS = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
    SCHEMA_REGISTRY_ARN                                        = var.schema_registry_arn
    STRIPE_API_KEY                                             = data.aws_secretsmanager_secret_version.stripe.secret_string
  })
}
