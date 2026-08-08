data "aws_secretsmanager_secret_version" "auth_db" {
  secret_id = var.auth_db_secret_arn
}

data "aws_secretsmanager_secret_version" "auth_jwt" {
  secret_id = "saas/${var.environment}/auth-jwt"
}

locals {
  auth_jwt = jsondecode(data.aws_secretsmanager_secret_version.auth_jwt.secret_string)
}

resource "aws_secretsmanager_secret" "auth_service" {
  name                    = "saas/auth-service"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "auth_service" {
  secret_id = aws_secretsmanager_secret.auth_service.id
  secret_string = jsonencode({
    DATABASE_URL       = "postgresql://${local.db.username}:${local.db.password}@${local.db.endpoint}/${local.db.db_name}"
    JWT_SECRET         = local.auth_jwt.secret
    JWT_REFRESH_SECRET = local.auth_jwt.refresh_secret
    ACCESS_TOKEN_TTL   = "15m"
    REFRESH_TOKEN_TTL  = "7d"
  })
}
