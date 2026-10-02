# bootstrap layer

The **one-time, manually-applied** CI substrate for an environment. It is deliberately
kept out of the steady-state Terragrunt run graph: an administrator applies it once
per env, and from then on ordinary CI runs on what it created.

## What it stands up

| Component | Module | Purpose |
|-----------|--------|---------|
| Per-env toolchain image repo | `modules/bootstrap-ecr` | Immutable, scanned ECR repo `saas-<env>-bootstrap-runner`. Holds the pinned CI toolchain image jobs run inside. |
| Keyless scoped roles | `modules/gha-oidc` | GitHub OIDC provider + `tf-plan` (read-only), `tf-apply` (steady-state deployer), `cluster-bootstrap` (gated break-glass admin). |
| Persistent in-VPC runner | `modules/gha-runner` | AL2023 EC2 (ASG, self-healing) in private subnets. The CI path to the **private** EKS API — no VPN. Thin instance profile: SSM + read PAT + pull image, **no deploy rights**. |
| Least-privilege cluster access | this layer | EKS access entries: `cluster-bootstrap` role → cluster-admin (gated), `tf-apply` role → the `saas:ci-deployers` group (STANDARD). |
| ci-deployer RBAC | `modules/ci-deployer-rbac` | The escalation-capable (`bind`/`escalate`) ClusterRole the deployer runs as. Not cluster-admin. |

## The access model (why this exists)

- **Runner host is dumb and non-privileged.** It only executes jobs; every AWS action
  is a short-lived GitHub OIDC federation into one of the scoped roles. A compromised
  host cannot deploy or touch the cluster.
- **No standing cluster-admin.** Steady-state CI (the `tf-apply` role) acts cluster-side
  only as the `ci-deployers` group. The sole cluster-admin principal is the gated
  `cluster-bootstrap` role, assumable only through an approved deployment to the
  protected GitHub Environment.
- **Humans use AWS Verified Access** (`modules/verified-access`) to reach the private
  endpoint. The runner uses VPC networking. The two paths are independent; neither is
  a VPN.
- **Immutable toolchain.** terraform/terragrunt/kubectl/helm/awscli/checkov are pinned
  in `docker/Dockerfile` and scanned on push — no boot-time install drift.

## One-time procedure (per env)

Prereqs: `00-network` and `10-platform` already applied; you hold cluster-admin
(`include_caller_as_cluster_admin = true` on the platform EKS module).

```bash
# 1. Apply the bootstrap layer (creates ECR, OIDC roles, runner, access entries, RBAC)
cd live/<env>/bootstrap && terragrunt apply

# 2. Seed the runner registration PAT (GitHub PAT with manage-runners scope), then
#    cycle the ASG so the instance registers.
aws secretsmanager put-secret-value \
  --secret-id "$(terragrunt output -raw runner_pat_secret_arn)" \
  --secret-string "<github-pat>"
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$(terragrunt output -raw runner_asg_name)"

# 3. Build + push the per-env toolchain image (or run the bootstrap-image workflow)
#    -> Actions ▸ bootstrap-image ▸ Run (environment: <env>)

# 4. Wire the repo/Environment to the created roles:
#      secret AWS_DEPLOY_ROLE_ARN        = terragrunt output gha_tf_apply_role_arn
#      var    AWS_ROLE_CLUSTER_BOOTSTRAP = terragrunt output gha_cluster_bootstrap_role_arn
#      var    BOOTSTRAP_IMAGE            = terragrunt output toolchain_repository_url

# 5. Protect the GitHub Environment named after the env (required reviewers) so the
#    gated cluster-bootstrap role can only be assumed through an approved deployment.
```

## After bootstrap

- Steady-state `infra.yml` moves to `runs-on: [self-hosted, vpc]` and runs inside
  `${BOOTSTRAP_IMAGE}:<env>`, assuming the `tf-apply` role (the `ci-deployers` group).
- `cluster-bootstrap.yml` re-applies just the RBAC (`-target=module.ci_deployer_rbac`)
  as the gated admin, for idempotent recovery without a human on Verified Access.
- Once every deploy path uses the `tf-apply` role, set the platform EKS module's
  `include_caller_as_cluster_admin = false` to remove the last standing cluster-admin.

## Notes

- `create_oidc_provider`: leave `true` in the first env of an account; set `false` and
  pass `oidc_provider_arn` for later envs sharing that account.
- `map_deployer_access_entry` / `manage_ci_deployer_rbac` / `create_gated_admin_access_entry`
  are individually toggleable to stage the migration.
