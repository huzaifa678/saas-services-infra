data "aws_secretsmanager_secret_version" "api_gateway_input" {
  secret_id = "saas/api-gateway-input"
}

resource "aws_secretsmanager_secret" "api_gateway" {
  name                    = "saas/api-gateway"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "api_gateway" {
  secret_id = aws_secretsmanager_secret.api_gateway.id
  secret_string = jsonencode({
    JWT_SECRET        = local.api_input.JWT_SECRET
    REDIS_URL         = "redis://${var.redis_endpoint}:6379"
    KEYCLOAK_JWKS_URL = var.keycloak_jwks_url
  })
}
