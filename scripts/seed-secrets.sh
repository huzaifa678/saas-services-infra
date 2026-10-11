#!/usr/bin/env bash

set -euo pipefail

ENV="${1:?usage: seed-secrets.sh <dev|test|prod>}"
REGION="${AWS_REGION:-us-east-1}"
ENC_FILE="secrets.${ENV}.enc.env"   # SOPS-encrypted (committed) — preferred source
ENV_FILE="secrets.${ENV}.env"       # plaintext (gitignored) — fallback

# Load the TF_VAR_* values. Prefer the SOPS/age-encrypted file (decrypted in memory
# to a temp file, never written to the repo); fall back to a local plaintext file.
if [[ -f "$ENC_FILE" ]]; then
  command -v sops >/dev/null 2>&1 || { echo "sops is required to read $ENC_FILE (install sops + age; set SOPS_AGE_KEY_FILE)"; exit 1; }
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  sops --decrypt "$ENC_FILE" > "$tmp"
  set -a; source "$tmp"; set +a
  echo "loaded $ENC_FILE (sops/age)"
elif [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
  echo "loaded $ENV_FILE (plaintext fallback)"
else
  echo "missing $ENC_FILE (sops) or $ENV_FILE (plaintext) — one must hold the TF_VAR_* lines"; exit 1
fi

put() {
  local name="$1" value="$2"
  [[ -n "$value" ]] || { echo "skip $name (empty source value)"; return 0; }
  if aws secretsmanager describe-secret --secret-id "$name" --region "$REGION" >/dev/null 2>&1; then
    aws secretsmanager put-secret-value --secret-id "$name" \
      --secret-string "$value" --region "$REGION" >/dev/null
    echo "updated $name"
  else
    aws secretsmanager create-secret --name "$name" \
      --secret-string "$value" --region "$REGION" >/dev/null
    echo "created $name"
  fi
}

put "saas/${ENV}/stripe-api-key" "${TF_VAR_stripe_api_key:-}"

put "saas/${ENV}/auth-jwt" "$(jq -nc \
  --arg s "${TF_VAR_auth_jwt_secret:-}" \
  --arg r "${TF_VAR_auth_jwt_refresh_secret:-}" \
  '{secret:$s, refresh_secret:$r}')"

put "saas/${ENV}/opensearch-master" "$(jq -nc \
  --arg u "${TF_VAR_opensearch_master_username:-admin}" \
  --arg p "${TF_VAR_opensearch_master_password:-}" \
  '{username:$u, password:$p}')"

put "saas/${ENV}/auth0" "$(jq -nc \
  --arg i "${TF_VAR_ava_oidc_client_id:-}" \
  --arg c "${TF_VAR_ava_oidc_client_secret:-}" \
  '{client_id:$i, client_secret:$c}')"

# LLM provider keys read by usage-service (RAG embedding) and agent-service.
put "saas/${ENV}/llm-api-keys" "$(jq -nc \
  --arg o "${TF_VAR_openai_api_key:-}" \
  --arg a "${TF_VAR_anthropic_api_key:-}" \
  '{OPENAI_API_KEY:$o, ANTHROPIC_API_KEY:$a}')"

# Backstage portal input, composed by the backstage module into the backstage-app
# secret. NOTE: account-global (no <env> in the id), so only seed it from the env
# file that actually carries the backstage values — guarded below so a run for an
# env without them does NOT clobber the shared secret with empty fields.
#
# GitHub auth is the shared SAAS gitops GitHub App (not a PAT): Backstage's
# GithubAppConfig needs appId/clientId/clientSecret/webhookSecret/privateKey, which
# become GITHUB_APP_* env on the pod (app-config.yaml integrations.github.apps).
# The PEM is single-line in the enc.env as base64 (a PEM has newlines, dotenv does
# not) and decoded here; jq re-encodes the newlines into the Secrets Manager JSON
# and ESO decodes them back, so the pod receives a valid multi-line PEM.
# KEYCLOAK_CLIENT_SECRET + ARGOCD_AUTH_TOKEN are generated in-cluster by the CD repo
# (secretGeneration.enabled; see CD docs/backstage-secret-generation.md), so they
# are intentionally NOT seeded here.
if [[ -n "${TF_VAR_backstage_github_app_id:-}" ]]; then
  put "saas/backstage-input" "$(jq -nc \
    --arg id "${TF_VAR_backstage_github_app_id:-}" \
    --arg ci "${TF_VAR_backstage_github_app_client_id:-}" \
    --arg cs "${TF_VAR_backstage_github_app_client_secret:-}" \
    --arg ws "${TF_VAR_backstage_github_app_webhook_secret:-}" \
    --arg pk "$(printf '%s' "${TF_VAR_backstage_github_app_private_key:-}" | base64 --decode)" \
    '{GITHUB_APP_ID:$id, GITHUB_APP_CLIENT_ID:$ci, GITHUB_APP_CLIENT_SECRET:$cs, GITHUB_APP_WEBHOOK_SECRET:$ws, GITHUB_APP_PRIVATE_KEY:$pk}')"
else
  echo "skip saas/backstage-input (no backstage App TF_VARs set for env=${ENV})"
fi

echo "done. seeded secrets for env=${ENV} in ${REGION}."
echo "note: api-gateway reads the pre-existing 'saas/api-gateway-input' secret (JWT_SECRET) — not managed here."
echo "note: the self-hosted runner's GitHub App key ('saas-${ENV}-gha-runner-app-key') is seeded by 'make register-runner', not here."
