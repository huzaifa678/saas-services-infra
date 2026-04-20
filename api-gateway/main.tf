data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "saas-state-bucket-399849"
    key    = "saas-services/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_secretsmanager_secret_version" "api_gateway_input" {
  secret_id = "saas/api-gateway-input"
}

locals {
  common = data.terraform_remote_state.common.outputs
}

resource "aws_secretsmanager_secret" "api_gateway" {
  name                    = "saas/api-gateway"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "api_gateway" {
  secret_id = aws_secretsmanager_secret.api_gateway.id
  secret_string = jsonencode({
    JWT_SECRET        = local.api_input.JWT_SECRET
    REDIS_URL         = "redis://${local.common.redis_endpoint}:6379"
    KEYCLOAK_JWKS_URL = var.keycloak_jwks_url
  })
}
