#!/usr/bin/env bash
# verify-apply.sh — exhaustive pre-apply check for one or more environments.
#
# Catches what `terraform plan` alone won't:
#   * unexpected destroys / replacements (the IRSA -> Pod Identity trust swap
#     must be in-place; anything getting recreated is a red flag)
#   * IAM role-name collisions before the apply tries to create them
#   * plan-time provider errors per env
#
# Then applies only the FREE parts (module.iam) first to flush any IAM-specific
# apply errors that plan can't see, before you green-light the full apply.
#
# Usage:
#   scripts/verify-apply.sh                 # runs dev + test
#   scripts/verify-apply.sh dev             # single env
#   scripts/verify-apply.sh dev test prod   # explicit list
#   APPLY_IAM=0 scripts/verify-apply.sh     # plan-only, skip the iam apply
#
# Requires: terraform, jq, awscli (with creds for the target account).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ENVS=("$@")
# Default to dev only — it's the one env with a checked-in secrets.<env>.env.
# Pass envs explicitly to test others, e.g. `verify-apply.sh dev test`.
[[ ${#ENVS[@]} -eq 0 ]] && ENVS=(dev)

APPLY_IAM="${APPLY_IAM:-1}"

# Resources we EXPECT to be created or updated by the Pod Identity migration.
# Anything outside this list showing up as create/update is worth a human look.
EXPECTED_CHANGES_REGEX='module\.(iam|eks)\.aws_(iam_role|iam_policy|iam_role_policy_attachment|eks_addon|eks_pod_identity_association)\.|^aws_eks_pod_identity_association\.this'

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

fail=0

for env in "${ENVS[@]}"; do
  echo
  bold "================================================================"
  bold " ENV: $env"
  bold "================================================================"

  env_dir="environments/$env"
  backend="$env_dir/backend.hcl"
  tfvars="$env_dir/terraform.tfvars"
  secrets="secrets.${env}.env"

  if [[ ! -f "$backend" ]] || [[ ! -f "$tfvars" ]]; then
    red "  missing $backend or $tfvars — skipping"
    fail=1
    continue
  fi

  # Sensitive vars (DB passwords, API keys, etc.) live in secrets.<env>.env
  # as `export TF_VAR_xxx=...` lines. Source them into this subshell only.
  if [[ -f "$secrets" ]]; then
    bold "[0/6] sourcing $secrets"
    # shellcheck disable=SC1090
    set -a; source "$secrets"; set +a
    green "      ok"
  else
    yellow "      no $secrets found — plan will fail if env has required sensitive vars"
  fi

  plan_file=".tfplan.${env}"

  # ── 1. init ────────────────────────────────────────────────────────────────
  bold "[1/6] terraform init ($env)"
  terraform init -reconfigure -backend-config="$backend" >/dev/null
  green "      ok"

  # ── 2. fmt + validate ──────────────────────────────────────────────────────
  bold "[2/6] terraform fmt -check + validate"
  if ! terraform fmt -check -recursive >/dev/null; then
    red "      fmt drift — run 'terraform fmt -recursive'"
    fail=1
  fi
  terraform validate >/dev/null
  green "      ok"

  # ── 3. plan ────────────────────────────────────────────────────────────────
  # -detailed-exitcode: 0 = no diff, 1 = real error, 2 = diff present (success).
  # Disable `set -e` around the call so we can read the real exit code.
  bold "[3/6] terraform plan -> $plan_file"
  set +e
  terraform plan -input=false -var-file="$tfvars" -out="$plan_file" -detailed-exitcode
  rc=$?
  set -e
  case $rc in
    0) green "      ok (no changes)" ;;
    2) green "      ok (diff present)" ;;
    *) red "      plan failed for $env (exit $rc)"; fail=1; continue ;;
  esac

  # ── 4. inspect plan for risky actions ──────────────────────────────────────
  bold "[4/6] inspecting plan for delete / replace actions"
  plan_json="$(terraform show -json "$plan_file")"

  destructive="$(echo "$plan_json" | jq -r '
    .resource_changes[]
    | select(.change.actions | any(. == "delete") or any(. == "replace") or (. == ["delete","create"]))
    | "\(.change.actions | join(",")) \(.address)"
  ')"

  if [[ -n "$destructive" ]]; then
    red "      DESTRUCTIVE CHANGES FOUND — review before applying:"
    echo "$destructive" | sed 's/^/        /'
    fail=1
  else
    green "      no destroys / replacements"
  fi

  bold "[4b/6] listing all create/update actions"
  echo "$plan_json" | jq -r '
    .resource_changes[]
    | select(.change.actions | any(. == "create") or any(. == "update"))
    | "\(.change.actions | join(",")) \(.address)"
  ' | sed 's/^/        /'

  unexpected="$(echo "$plan_json" | jq -r --arg re "$EXPECTED_CHANGES_REGEX" '
    .resource_changes[]
    | select(.change.actions | any(. == "create") or any(. == "update"))
    | select(.address | test($re) | not)
    | .address
  ')"
  if [[ -n "$unexpected" ]]; then
    yellow "      heads-up: changes outside the Pod Identity migration scope:"
    echo "$unexpected" | sed 's/^/        /'
  fi

  # ── 5. pre-flight: IAM role-name collisions ────────────────────────────────
  bold "[5/6] checking for IAM role name collisions in AWS"
  new_roles="$(echo "$plan_json" | jq -r '
    .resource_changes[]
    | select(.type == "aws_iam_role" and (.change.actions | any(. == "create")))
    | .change.after.name // empty
  ')"
  if [[ -z "$new_roles" ]]; then
    green "      no new IAM roles being created"
  else
    while IFS= read -r role; do
      [[ -z "$role" ]] && continue
      if aws iam get-role --role-name "$role" >/dev/null 2>&1; then
        red "      collision: IAM role '$role' already exists in this account"
        fail=1
      else
        green "      ok: $role does not exist"
      fi
    done <<< "$new_roles"
  fi

  # ── 6. targeted apply of IAM (free) to flush apply-time IAM errors ────────
  if [[ "$APPLY_IAM" == "1" ]]; then
    bold "[6/6] terraform apply -target=module.iam   (IAM is always free)"
    yellow "      this DOES touch AWS but only IAM resources (\$0 cost)"
    read -r -p "      proceed with iam-only apply for $env? [y/N] " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
      terraform apply -input=false -auto-approve \
        -var-file="$tfvars" \
        -target=module.iam
      green "      iam apply ok — full apply should now succeed"
    else
      yellow "      skipped iam apply"
    fi
  else
    bold "[6/6] skipped iam apply (APPLY_IAM=0)"
  fi

  rm -f "$plan_file"
done

echo
if [[ $fail -ne 0 ]]; then
  red "FAILED — fix the issues above before running 'terraform apply'"
  exit 1
fi
green "ALL CHECKS PASSED for: ${ENVS[*]}"
green "Safe to run: terraform apply -var-file=environments/<env>/terraform.tfvars"
