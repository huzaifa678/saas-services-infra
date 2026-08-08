#!/usr/bin/env bash

set -euo pipefail

ENV="${1:?usage: seed-secrets.sh <dev|test|prod>}"
REGION="${AWS_REGION:-us-east-1}"
ENV_FILE="secrets.${ENV}.env"

[[ -f "$ENV_FILE" ]] || { echo "missing $ENV_FILE (holds the export TF_VAR_* lines)"; exit 1; }
source "$ENV_FILE"

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

echo "done. seeded secrets for env=${ENV} in ${REGION}."
echo "note: api-gateway reads the pre-existing 'saas/api-gateway-input' secret (JWT_SECRET) — not managed here."
