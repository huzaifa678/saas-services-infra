data "aws_secretsmanager_secret_version" "backstage_input" {
  secret_id = "saas/backstage-input"
}

resource "random_password" "backend_secret" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "backstage_app" {
  name                    = "backstage-app"
  description             = "Backstage portal runtime config (OIDC, GitHub, ArgoCD, backend key)."
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "backstage_app" {
  secret_id = aws_secretsmanager_secret.backstage_app.id
  secret_string = jsonencode({
    KEYCLOAK_METADATA_URL  = "https://${var.keycloak_host}/realms/${var.keycloak_realm}/.well-known/openid-configuration"
    KEYCLOAK_CLIENT_ID     = var.keycloak_client_id
    KEYCLOAK_CLIENT_SECRET = local.input.KEYCLOAK_CLIENT_SECRET

    GITHUB_TOKEN = local.input.GITHUB_TOKEN

    ARGOCD_AUTH_TOKEN = local.input.ARGOCD_AUTH_TOKEN

    BACKEND_SECRET = base64encode(random_password.backend_secret.result)
  })
}
