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
}

resource "aws_secretsmanager_secret" "api_gateway" {
  name                    = "saas/api-gateway"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "api_gateway" {
  secret_id = aws_secretsmanager_secret.api_gateway.id
  secret_string = jsonencode({
    JWT_SECRET        = var.gateway_jwt_secret
    REDIS_URL         = local.common.redis_endpoint
    KEYCLOAK_JWKS_URL = var.keycloak_jwks_url
  })
}
