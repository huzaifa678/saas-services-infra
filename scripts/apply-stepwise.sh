set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ENV="${1:-dev}"
FROM="${FROM:-1}"
AUTO_APPROVE="${AUTO_APPROVE:-0}"

backend="environments/$ENV/backend.hcl"
tfvars="environments/$ENV/terraform.tfvars"
secrets="secrets.${EN$n? [y/N/skip] " ans
    case "$ans" in
      y|Y) ;;
      s|skip) yellow "  skipped"; rm -f ".tfplan.step${n}"; return 0 ;;
      *) red "  aborted at step $n — resume with: FROM=$n $0 $ENV"; rm -f ".tfplan.step${n}"; exit 1 ;;
    esac
  fi

  bold "  apply"
  terraform apply -input=false ".tfplan.step${n}"
  rm -f ".tfplan.step${n}"
  green "  step $n done"

  if [[ "$AUTO_APPROVE" != "1" ]]; then
    echo
    yellow "  (optional) verify in another shell, e.g.:"
    echo "    aws iam list-roles --query 'Roles[?starts_with(RoleName, \`saas\`)].RoleName'"
    echo "    aws eks list-addons --cluster-name \$CLUSTER_NAME"
    echo "    aws eks list-pod-identity-associations --cluster-name \$CLUSTER_NAME"
    echo "    kubectl get pods -A | grep -E 'cert-manager|external-dns|external-secrets|karpenter|aws-load-balancer|ebs-csi'"
    read -r -p "  continue to next step? [Y/n] " ans
    [[ "$ans" == "n" || "$ans" == "N" ]] && { red "  paused. resume with: FROM=$((n+1)) $0 $ENV"; exit 0; }
  fi
}

for i in "${!STEPS[@]}"; do
  n=$((i + 1))
  [[ $n -lt $FROM ]] && continue
  label="${STEPS[$i]%%|*}"
  targets="${STEPS[$i]#*|}"
  run_step "$n" "$label" "$targets"
done

echo
green "================================================================"
green " ALL STEPS COMPLETE — full migration applied"
green "================================================================"
echo
echo "Next:"
echo "  1. Trigger pod refresh:  argocd app sync pod-identity-refresh"
echo "  2. Verify creds:         kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets | grep -i 'pod-identity\\|credential'"
echo "  3. Run any remaining out-of-scope changes via plain: terraform apply -var-file=$tfvars"
V}.env"

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

[[ -f "$backend" ]] || { red "missing $backend"; exit 1; }
[[ -f "$tfvars"  ]] || { red "missing $tfvars";  exit 1; }
if [[ -f "$secrets" ]]; then
  set -a; # shellcheck disable=SC1090
  source "$secrets"
  set +a
else
  yellow "no $secrets — apply will fail if env has required sensitive vars"
fi

bold "init"
terraform init -reconfigure -backend-config="$backend" >/dev/null
green "ok"

# ── ordered target list ─────────────────────────────────────────────────────
#
# Format: "<label>|<target1> <target2> ..."
# Targets in the same step are applied in one `terraform apply` call (Terraform
# orders them internally via its dep graph). Steps are applied one at a time.
#
# Order matters across steps:
#   1. iam module — provides ebs_csi_role_arn that step 3 needs
#   2. core addons that have no IAM dep (vpc-cni, kube-proxy, coredns)
#   3. pod-identity-agent — must exist before any pod identity association
#      can actually deliver creds
#   4. ebs-csi addon — needs both ebs_csi_role_arn (step 1) and agent (step 3)
#   5. pod identity associations — the binding from SA to role
#
STEPS=(
  "iam module (all roles + policies + karpenter SQS)|module.iam"
  "core EKS addons: vpc-cni|module.eks.aws_eks_addon.vpc_cni"
  "core EKS addons: kube-proxy|module.eks.aws_eks_addon.kube_proxy"
  "core EKS addons: coredns|module.eks.aws_eks_addon.coredns"
  "eks-pod-identity-agent addon|module.eks.aws_eks_addon.pod_identity_agent"
  "aws-ebs-csi-driver addon (uses ebs_csi_role)|module.eks.aws_eks_addon.ebs_csi"
  "pod identity associations (all 6)|aws_eks_pod_identity_association.this"
)

run_step() {
  local n="$1" label="$2" targets="$3"

  echo
  bold "================================================================"
  bold " STEP $n / ${#STEPS[@]} — $label"
  bold "================================================================"
  echo "  targets:"
  for t in $targets; do echo "    - $t"; done
  echo

  # Show plan for just these targets first
  local target_args=()
  for t in $targets; do target_args+=("-target=$t"); done

  bold "  plan (targeted)"
  set +e
  terraform plan -input=false -var-file="$tfvars" "${target_args[@]}" \
    -out=".tfplan.step${n}" -detailed-exitcode
  local rc=$?
  set -e

  case $rc in
    0) yellow "  no changes for this step — skipping apply"; rm -f ".tfplan.step${n}"; return 0 ;;
    2) ;;
    *) red "  plan failed (exit $rc)"; exit 1 ;;
  esac

  # Inspect for destroy/replace
  local risky
  risky="$(terraform show -json ".tfplan.step${n}" | jq -r '
    .resource_changes[]
    | select(.change.actions | any(. == "delete") or any(. == "replace"))
    | "\(.change.actions | join(",")) \(.address)"
  ')"
  if [[ -n "$risky" ]]; then
    red "  DESTRUCTIVE actions in this step:"
    echo "$risky" | sed 's/^/    /'
    read -r -p "  proceed anyway? [y/N] " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || { rm -f ".tfplan.step${n}"; exit 1; }
  fi

  if [[ "$AUTO_APPROVE" != "1" ]]; then
    read -r -p "  apply step 