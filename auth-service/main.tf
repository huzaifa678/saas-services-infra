data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "saas-state-bucket-399849"
    key    = "saas-services/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_secretsmanager_secret" "auth_service" {
  name                    = "saas/auth-service"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "auth_service" {
  secret_id = aws_secretsmanager_secret.auth_service.id
  secret_string = jsonencode({
    DATABASE_URL       = "postgresql://${local.db.username}:${local.db.password}@${local.db.endpoint}/${local.db.db_name}"
    JWT_SECRET         = var.auth_jwt_secret
    JWT_REFRESH_SECRET = var.auth_jwt_refresh_secret
    ACCESS_TOKEN_TTL   = "15m"
    REFRESH_TOKEN_TTL  = "7d"
  })
}
