#!/usr/bin/env bash
# teardown.sh — pre-destroy cleanup for one environment, so that a subsequent
# `terragrunt run-all destroy` actually completes instead of hanging on
# dependency-violation errors.
#
# WHY THIS EXISTS
#   Several AWS resources in a running env are NOT created by Terraform/Terragrunt
#   and therefore are NOT removed by `terragrunt destroy`. Left behind, they keep
#   the VPC/subnets/security-groups in use and the destroy fails:
#
#     * NLBs created by Kubernetes `type: LoadBalancer` Services (the per-namespace
#       nginx-gateway-lb Services + anything the apps expose). Each holds ENIs in
#       the private subnets and a security-group reference.
#     * EC2 nodes Karpenter provisions out-of-band (not a TF-managed node group).
#       Each holds a primary ENI + VPC-CNI secondary ENIs and keeps the cluster /
#       node security groups in use.
#     * Leftover "available" ENIs and LB-created security groups after the above
#       are torn down — the classic "DependencyViolation: … has a dependent object"
#       that blocks subnet / SG / VPC deletion.
#     * ECR repositories that still hold images (the repos are created with
#       force_delete=false, so a non-empty repo refuses to delete).
#     * RDS instances with deletion_protection=true (on in test/prod per guardrails).
#
#   ArgoCD (installed by 50-addons-helm) continuously reconciles the cluster, so it
#   would recreate anything we delete. We stop its controllers first, but keep the
#   AWS Load Balancer Controller and Karpenter running so they can gracefully
#   deprovision the NLBs and nodes we delete.
#
# ORDER
#   0. resolve cluster/vpc/region   1. stop ArgoCD reconciliation
#   2. delete LoadBalancer Services 3. delete Karpenter NodePools/NodeClaims
#   4. delete Crossplane claims     5. AWS sweep: ELBs, SGs, available ENIs
#   6. empty ECR repos              7. disable RDS deletion protection
#   8. print (or run) the destroy
#
#   Only AFTER this does the layer destroy run — reverse dependency order is handled
#   by `terragrunt run-all destroy` / `make destroy-all`.
#
# USAGE
#   scripts/teardown.sh <env>                 # cleanup only, then print next step
#   RUN_DESTROY=1 scripts/teardown.sh <env>   # cleanup, then run terragrunt destroy
#   AUTO_APPROVE=1 scripts/teardown.sh <env>  # skip the confirmation prompt
#   SKIP_K8S=1 scripts/teardown.sh <env>      # cluster already gone: AWS sweep only
#   REGION=us-west-2 scripts/teardown.sh <env>
#
#   <env> is one of dev | test | prod and is REQUIRED (no default — this is destructive).
#
# Requires: terragrunt, terraform, aws, kubectl, jq.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
step()   { echo; bold "── $* ──"; }

ENV="${1:-}"
case "$ENV" in
  dev|test|prod) ;;
  *) red "usage: $0 <dev|test|prod>   (env is required)"; exit 2 ;;
esac

AUTO_APPROVE="${AUTO_APPROVE:-0}"
RUN_DESTROY="${RUN_DESTROY:-0}"
SKIP_K8S="${SKIP_K8S:-0}"
WAIT_SECS="${WAIT_SECS:-300}"   # per-wait timeout for LBs/nodes to drain

for bin in terragrunt aws kubectl jq; do
  command -v "$bin" >/dev/null 2>&1 || { red "missing required tool: $bin"; exit 1; }
done

live="live/${ENV}"
[[ -d "$live" ]] || { red "no $live — wrong repo root or env?"; exit 1; }

# Region from env.hcl (fallback us-east-1), overridable via REGION.
REGION="${REGION:-$(grep -E '^\s*region\s*=' "$live/env.hcl" 2>/dev/null | head -1 | sed -E 's/.*"([^"]+)".*/\1/')}"
REGION="${REGION:-us-east-1}"
export AWS_REGION="$REGION" AWS_DEFAULT_REGION="$REGION"

tg_out() { # tg_out <layer> <output-name>  -> raw value or empty
  terragrunt output -raw "$2" --working-dir "$live/$1" 2>/dev/null || true
}

step "0. resolve cluster / vpc / account"
CLUSTER="$(tg_out 10-platform cluster_name)"
VPC_ID="$(tg_out 00-network vpc_id)"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
echo "  env=$ENV region=$REGION account=${ACCOUNT:-?}"
echo "  cluster=${CLUSTER:-<unknown>} vpc=${VPC_ID:-<unknown>}"
[[ -z "$CLUSTER" ]] && yellow "  cluster_name not in state (already destroyed?) — k8s steps will be skipped"
[[ -z "$VPC_ID"  ]] && yellow "  vpc_id not in state — the ENI/SG sweep will be skipped"

if [[ "$AUTO_APPROVE" != "1" ]]; then
  echo
  red "This DELETES load balancers, Karpenter nodes, ECR images and disables RDS"
  red "deletion protection in the '$ENV' environment (account ${ACCOUNT:-?}, $REGION)."
  read -r -p "  Type the cluster name '${CLUSTER:-$ENV}' to continue: " ans
  [[ "$ans" == "${CLUSTER:-$ENV}" ]] || { red "  aborted."; exit 1; }
fi

# ── Kubernetes-side cleanup ──────────────────────────────────────────────────
if [[ "$SKIP_K8S" == "1" || -z "$CLUSTER" ]]; then
  yellow "skipping Kubernetes cleanup (SKIP_K8S=$SKIP_K8S, cluster='${CLUSTER:-}')"
else
  step "kubeconfig for $CLUSTER"
  if aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1 \
     && kubectl version >/dev/null 2>&1; then

    step "1. stop ArgoCD reconciliation (so it stops recreating what we delete)"
    # Keep the LB controller + Karpenter running; only silence Argo.
    kubectl -n argocd scale statefulset/argocd-application-controller --replicas=0 2>/dev/null || true
    kubectl -n argocd scale deploy/argocd-applicationset-controller --replicas=0 2>/dev/null || true
    # Drop Argo's resource finalizers so a later namespace/app delete can't hang.
    for app in $(kubectl -n argocd get applications.argoproj.io -o name 2>/dev/null); do
      kubectl -n argocd patch "$app" --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
    done

    step "2. delete type=LoadBalancer Services (removes NLBs + their ENIs)"
    kubectl get svc -A -o json 2>/dev/null \
      | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace) \(.metadata.name)"' \
      | while read -r ns name; do
          [[ -z "$ns" ]] && continue
          echo "  deleting svc $ns/$name"
          kubectl -n "$ns" delete svc "$name" --wait=false 2>/dev/null || true
        done
    # Wait for the controller to actually delete the ELBv2 objects in this VPC.
    if [[ -n "$VPC_ID" ]]; then
      echo "  waiting up to ${WAIT_SECS}s for load balancers to be removed…"
      end=$(( $(date +%s) + WAIT_SECS ))
      while :; do
        left="$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null)"
        [[ -z "$left" || "$left" == "None" ]] && { green "  load balancers gone"; break; }
        [[ $(date +%s) -ge $end ]] && { yellow "  timeout — remaining LBs handled in the AWS sweep"; break; }
        sleep 10
      done
    fi

    step "3. delete Karpenter NodePools / NodeClaims (drains + terminates nodes)"
    kubectl delete nodepools.karpenter.sh --all --wait=false 2>/dev/null || true
    kubectl delete nodeclaims.karpenter.sh --all --wait=false 2>/dev/null || true
    # Now stop Karpenter so it doesn't try to launch replacements.
    kubectl -n karpenter scale deploy/karpenter --replicas=0 2>/dev/null \
      || kubectl -n kube-system scale deploy/karpenter --replicas=0 2>/dev/null || true
    if [[ -n "$CLUSTER" ]]; then
      echo "  waiting up to ${WAIT_SECS}s for Karpenter EC2 instances to terminate…"
      end=$(( $(date +%s) + WAIT_SECS ))
      while :; do
        ids="$(aws ec2 describe-instances \
          --filters "Name=tag:karpenter.sh/discovery,Values=$CLUSTER" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
          --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null)"
        [[ -z "$ids" || "$ids" == "None" ]] && { green "  Karpenter nodes gone"; break; }
        [[ $(date +%s) -ge $end ]] && { yellow "  timeout — will force-terminate: $ids"; aws ec2 terminate-instances --instance-ids $ids >/dev/null 2>&1 || true; break; }
        sleep 15
      done
    fi

    step "4. delete Crossplane claims (so Crossplane deprovisions out-of-band AWS resources)"
    for kind in appdatabases.platform.saas.example appcaches.platform.saas.example; do
      if kubectl get crd "$kind" >/dev/null 2>&1; then
        kubectl delete "$kind" --all -A --wait=false 2>/dev/null || true
      fi
    done
  else
    yellow "  cluster unreachable (private endpoint or already gone) — skipping k8s steps,"
    yellow "  relying on the AWS sweep below. Re-run from the VPC/runner if NLBs remain."
  fi
fi

# ── AWS-level sweep (belt-and-suspenders, needs the VPC id) ──────────────────
if [[ -n "$VPC_ID" ]]; then
  step "5a. delete any ELBv2 load balancers still in $VPC_ID"
  for arn in $(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null); do
    [[ "$arn" == "None" ]] && continue
    echo "  deleting LB $arn"
    aws elbv2 delete-load-balancer --load-balancer-arn "$arn" 2>/dev/null || true
  done
  # Orphaned target groups in the VPC.
  for tg in $(aws elbv2 describe-target-groups --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text 2>/dev/null); do
    [[ "$tg" == "None" ]] && continue
    aws elbv2 delete-target-group --target-group-arn "$tg" 2>/dev/null || true
  done

  step "5b. delete leftover LB-controller security groups (tagged for the cluster)"
  if [[ -n "$CLUSTER" ]]; then
    for sg in $(aws ec2 describe-security-groups \
          --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag-key,Values=elbv2.k8s.aws/cluster" \
          --query 'SecurityGroups[].GroupId' --output text 2>/dev/null); do
      [[ "$sg" == "None" ]] && continue
      echo "  deleting sg $sg"
      aws ec2 delete-security-group --group-id "$sg" 2>/dev/null || true
    done
  fi

  step "5c. delete stale 'available' ENIs in $VPC_ID (the usual VPC-destroy blocker)"
  for eni in $(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
        --query 'NetworkInterfaces[].NetworkInterfaceId' --output text 2>/dev/null); do
    [[ "$eni" == "None" ]] && continue
    echo "  deleting eni $eni"
    aws ec2 delete-network-interface --network-interface-id "$eni" 2>/dev/null || true
  done
else
  yellow "no VPC id — skipping ELB/SG/ENI sweep"
fi

# ── ECR: empty the repositories so they can be destroyed ─────────────────────
step "6. empty ECR repositories (force_delete=false means non-empty repos won't delete)"
repos="$(terragrunt output -json ecr_repository_urls --working-dir "$live/05-ecr" 2>/dev/null | jq -r 'keys[]?' 2>/dev/null)"
repos="$repos saas-${ENV}-bootstrap-runner"
for r in $repos; do
  [[ -z "$r" ]] && continue
  ids="$(aws ecr list-images --repository-name "$r" --query 'imageIds[*]' --output json 2>/dev/null)"
  if [[ -n "$ids" && "$ids" != "[]" && "$ids" != "null" ]]; then
    echo "  emptying ecr repo $r"
    aws ecr batch-delete-image --repository-name "$r" --image-ids "$ids" >/dev/null 2>&1 || true
  fi
done

# ── RDS: clear deletion protection (on in test/prod per guardrails) ──────────
step "7. disable RDS deletion protection for env=$ENV"
dbs="$(aws resourcegroupstaggingapi get-resources \
        --resource-type-filters rds:db \
        --tag-filters "Key=Environment,Values=$ENV" "Key=Project,Values=saas" \
        --query 'ResourceTagMappingList[].ResourceARN' --output text 2>/dev/null)"
for arn in $dbs; do
  [[ "$arn" == "None" ]] && continue
  id="${arn##*:db:}"
  echo "  $id: --no-deletion-protection"
  aws rds modify-db-instance --db-instance-identifier "$id" --no-deletion-protection --apply-immediately >/dev/null 2>&1 || true
done

# ── Hand off to terragrunt destroy ───────────────────────────────────────────
echo
green "================================================================"
green " pre-destroy cleanup complete for env=$ENV"
green "================================================================"
if [[ "$RUN_DESTROY" == "1" ]]; then
  step "8. terragrunt run-all destroy (reverse dependency order)"
  [[ "$AUTO_APPROVE" == "1" ]] && exec terragrunt run-all destroy --working-dir "$live" --terragrunt-non-interactive
  exec terragrunt run-all destroy --working-dir "$live"
else
  echo "Next — destroy the layers (reverse order is handled automatically):"
  echo "    make destroy-all ENV=$ENV"
  echo "  or: terragrunt run-all destroy --working-dir $live"
  echo
  echo "If a subnet/SG/VPC delete still fails with DependencyViolation, re-run this"
  echo "script (the ENI/LB sweep is idempotent) then retry the destroy."
fi
