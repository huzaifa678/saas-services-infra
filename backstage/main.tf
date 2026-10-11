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
  # KEYCLOAK_CLIENT_SECRET and ARGOCD_AUTH_TOKEN have no generator on the AWS side,
  # so they are seeded into saas/backstage-input by default. When the CD repo's
  # backstage chart generates them in-cluster (secretGeneration.enabled), set
  # generate_secrets_in_cluster = true here: the keys are omitted from backstage-app
  # (the pod gets them from the in-cluster backstage-generated Secret instead), and
  # you no longer seed them into backstage-input.
  # GitHub auth is the shared SAAS gitops GitHub App (not a PAT): Backstage's
  # GithubAppConfig reads these five GITHUB_APP_* keys (app-config.yaml
  # integrations.github.apps). They are seeded into saas/backstage-input by the
  # seed-secrets.sh backstage block; GITHUB_APP_PRIVATE_KEY arrives as a multi-line
  # PEM (base64 in the enc.env, decoded on seed) and passes through as-is.
  secret_string = jsonencode(merge(
    {
      KEYCLOAK_METADATA_URL     = "https://${var.keycloak_host}/realms/${var.keycloak_realm}/.well-known/openid-configuration"
      KEYCLOAK_CLIENT_ID        = var.keycloak_client_id
      GITHUB_APP_ID             = local.input.GITHUB_APP_ID
      GITHUB_APP_CLIENT_ID      = local.input.GITHUB_APP_CLIENT_ID
      GITHUB_APP_CLIENT_SECRET  = local.input.GITHUB_APP_CLIENT_SECRET
      GITHUB_APP_WEBHOOK_SECRET = local.input.GITHUB_APP_WEBHOOK_SECRET
      GITHUB_APP_PRIVATE_KEY    = local.input.GITHUB_APP_PRIVATE_KEY
      BACKEND_SECRET            = base64encode(random_password.backend_secret.result)
    },
    var.generate_secrets_in_cluster ? {} : {
      KEYCLOAK_CLIENT_SECRET = local.input.KEYCLOAK_CLIENT_SECRET
      ARGOCD_AUTH_TOKEN      = local.input.ARGOCD_AUTH_TOKEN
    },
  ))
}
