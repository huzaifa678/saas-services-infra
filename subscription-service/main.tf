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
  db     = local.common.subscription_db
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
