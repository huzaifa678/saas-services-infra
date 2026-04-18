data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "saas-state-bucket-399849"
    key    = "saas-services/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  common = data.terraform_remote_state.common.outputs
  db     = local.common.billing_db
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
    SPRING_DATA_REDIS_HOST         = local.common.redis_endpoint
    SPRING_DATA_REDIS_PORT         = "6379"
    SPRING_KAFKA_BOOTSTRAP_SERVERS = local.common.kafka_bootstrap_brokers
    SCHEMA_REGISTRY_ARN            = local.common.schema_registry_arn
    STRIPE_API_KEY                 = var.stripe_api_key
  })
}
