# bootstrap layer

The **account/CI identity substrate** for an environment — the ECR toolchain repo and
the keyless, scoped GitHub OIDC roles. It has **no infra dependency** and owns its own
CMK, so it can be applied **first**, before `00-network`. Applied once per env by an
administrator; ordinary CI then runs on what it created.

The CI substrate is split across three one-time layers by dependency:

| Layer | Holds | Depends on |
|---|---|---|
| **`bootstrap`** (this) | ECR toolchain repo, OIDC provider + scoped roles, own CMK | nothing |
| [`runner`](../runner) | Isolated runner VPC + self-hosted runner + peering to the app VPC | `bootstrap`, `00-network`, `10-platform` |
| [`45-rbac`](../45-rbac) | EKS access entries + ci-deployer RBAC | `10-platform`, `bootstrap` |

## What it stands up

| Component | Module | Purpose |
|-----------|--------|---------|
| Dedicated CMK | this layer | Encrypts the toolchain ECR repo. Owned here so the layer needs nothing from `00-network`. |
| Per-env toolchain image repo | `modules/bootstrap-ecr` | Immutable, scanned ECR repo `saas-<env>-bootstrap-runner`. Holds the pinned CI toolchain image jobs run inside. |
| Keyless scoped roles | `modules/gha-oidc` | GitHub OIDC provider + `tf-plan` (read-only), `tf-apply` (steady-state deployer), `cluster-bootstrap` (gated break-glass admin). |

## The access model (why this exists)

- **Runner host is dumb and non-privileged.** It only executes jobs; every AWS action
  is a short-lived GitHub OIDC federation into one of the scoped roles. A compromised
  host cannot deploy or touch the cluster.
- **No standing cluster-admin.** Steady-state CI (the `tf-apply` role) acts cluster-side
  only as the `ci-deployers` group. The sole cluster-admin principal is the gated
  `cluster-bootstrap` role, assumable only through an approved deployment to the
  protected GitHub Environment.
- **Humans use AWS Verified Access** (`modules/verified-access`) to reach the private
  endpoint. The runner uses its own peered VPC. The two paths are independent; neither
  is a VPN.
- **Immutable toolchain.** terraform/terragrunt/kubectl/helm/awscli/checkov are pinned
  in `docker/Dockerfile` and scanned on push — no boot-time install drift.

## One-time procedure (per env)

No prerequisites — this is the first thing applied.

```bash
# 1. Apply the bootstrap layer (creates the CMK, ECR repo, OIDC roles)
cd live/<env>/bootstrap && terragrunt apply

# 2. Build + push the per-env toolchain image (or run the bootstrap-image workflow)
#    -> Actions ▸ bootstrap-image ▸ Run (environment: <env>)

# 3. Wire the repo/Environment to the created roles:
#      secret AWS_DEPLOY_ROLE_ARN        = terragrunt output gha_tf_apply_role_arn
#      var    AWS_ROLE_CLUSTER_BOOTSTRAP = terragrunt output gha_cluster_bootstrap_role_arn
#      var    BOOTSTRAP_IMAGE            = terragrunt output toolchain_repository_url

# 4. Protect the GitHub Environment named after the env (required reviewers) so the
#    gated cluster-bootstrap role can only be assumed through an approved deployment.
```

Then stand up the [`runner`](../runner) layer (the self-hosted runner + its VPC) and,
after `10-platform`, [`45-rbac`](../45-rbac) (cluster access entries + ci-deployer RBAC).

## Notes

- `create_oidc_provider`: there is one GitHub OIDC provider per account. `dev` owns it
  (`true`); `test`/`prod` set `false` and the existing provider ARN is auto-derived from
  the account id (nothing to copy). Apply `dev`'s bootstrap first. If the envs are in
  separate accounts, set `true` in all three.
