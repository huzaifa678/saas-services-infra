data "aws_secretsmanager_secret_version" "agent_db" {
  secret_id = var.agent_db_secret_arn
}

# LLM provider keys (OpenAI + Anthropic) for langchain4j. Pre-provisioned out of
# band — same pattern as billing-service's Stripe key — as a JSON secret holding
# { "OPENAI_API_KEY": "...", "ANTHROPIC_API_KEY": "..." }.
data "aws_secretsmanager_secret_version" "llm" {
  secret_id = "saas/${var.environment}/llm-api-keys"
}

resource "aws_secretsmanager_secret" "agent_service" {
  name                    = "saas/agent-service"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "agent_service" {
  secret_id = aws_secretsmanager_secret.agent_service.id
  secret_string = jsonencode({
    SPRING_DATASOURCE_URL          = "jdbc:postgresql://${local.db.endpoint}/${local.db.db_name}"
    SPRING_DATASOURCE_USERNAME     = local.db.username
    SPRING_DATASOURCE_PASSWORD     = local.db.password
    SPRING_KAFKA_BOOTSTRAP_SERVERS = var.kafka_bootstrap_brokers
    # MSK SASL/IAM: the pod authenticates with its Pod Identity role (module
    # msk_client_identity["agent-service"] in 20-data). No secret material —
    # the IAM callback handler signs the connection with the assumed role.
    SPRING_KAFKA_PROPERTIES_SECURITY_PROTOCOL                  = "SASL_SSL"
    SPRING_KAFKA_PROPERTIES_SASL_MECHANISM                     = "AWS_MSK_IAM"
    SPRING_KAFKA_PROPERTIES_SASL_JAAS_CONFIG                   = "software.amazon.msk.auth.iam.IAMLoginModule required;"
    SPRING_KAFKA_PROPERTIES_SASL_CLIENT_CALLBACK_HANDLER_CLASS = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
    # langchain4j provider keys (application.properties reads OPENAI_API_KEY /
    # ANTHROPIC_API_KEY). agent-service publishes JSON to Kafka (no schema
    # registry yet), so no SCHEMA_REGISTRY_ARN — unlike billing-service.
    OPENAI_API_KEY    = local.llm.OPENAI_API_KEY
    ANTHROPIC_API_KEY = local.llm.ANTHROPIC_API_KEY
  })
}
