# Bootstrap, runner & cluster-RBAC setup guide

The CI substrate for an environment is split across **three** one-time layers by
dependency:

| Layer | Holds | Depends on | Applied by |
|---|---|---|---|
| **`bootstrap`** | ECR toolchain repo, GitHub OIDC provider + scoped roles (`tf-plan`/`tf-apply`/`cluster-bootstrap`), own CMK | **nothing** | Admin, first |
| **`runner`** | Isolated runner VPC + self-hosted runner + peering to the app VPC | **`bootstrap`** + **`00-network`** + **`10-platform`** | Admin, one-time |
| **`45-rbac`** | EKS access entries (gated cluster-admin + `tf-apply`→`ci-deployers`), ci-deployer RBAC | **`10-platform`** + **`bootstrap`** | Admin / gated `cluster-bootstrap` role |

All three are **outside the steady-state run graph**. For the rationale see the layer
READMEs ([bootstrap](../layers/bootstrap/README.md), [runner](../layers/runner/README.md),
[45-rbac](../layers/45-rbac/README.md)); this is the operational guide.

**See also:** [runner-registration.md](runner-registration.md) (the runner's GitHub App
auth, ASG self-healing and key rotation) and [apply-layer-workflow.md](apply-layer-workflow.md)
(how the steady-state `_apply-layer` workflow applies each layer).

---

## Why three layers (the dependency split)

- **`bootstrap`** is pure account/CI identity — ECR + OIDC roles — and owns its own
  CMK, so it has **zero** infra dependency and applies **first**. CI can assume
  `tf-apply` to provision everything else.
- **`runner`** is the self-hosted runner in its **own isolated VPC**, *peered* to the
  app VPC so it can reach the private EKS API. Isolated lifecycle; connected only by
  the peering the `runner-peering` module creates.
- **`45-rbac`** wires the CI identities into the cluster (access entries + RBAC), which
  needs a live cluster and the role ARNs `bootstrap` produced.

Inputs flow from earlier layers' remote state via the `dependency` blocks in
[`live/_envcommon/bootstrap.hcl`](../live/_envcommon/bootstrap.hcl),
[`live/_envcommon/runner.hcl`](../live/_envcommon/runner.hcl) and
[`live/_envcommon/45-rbac.hcl`](../live/_envcommon/45-rbac.hcl):

| Layer | Required input | From |
|---|---|---|
| `runner` | `ecr_repository_arn`, `toolchain_repository_url` | `bootstrap` |
| `runner` | `app_vpc_id`, `app_vpc_cidr`, `app_route_table_ids` | `00-network` |
| `runner` | `cluster_security_group_id`, `cluster_endpoint` | `10-platform` |
| `45-rbac` | `cluster_name/endpoint/ca` | `10-platform` |
| `45-rbac` | `cluster_bootstrap_role_arn`, `tf_apply_role_arn` | `bootstrap` |

Apply order:

```
bootstrap  (first — no deps)
00-network ─► 10-platform ─► 20-data ─► 30-edge ─► 40-observability ─► 45-rbac ─► 50-addons-helm
     │             │
     └── runner ───┘   (needs bootstrap + 00-network + 10-platform)
```

`make apply-all ENV=<env>` resolves this DAG automatically via `terragrunt run-all`.

---

## The runner's network model (VPC peering)

The runner lives in its **own VPC** (`modules/runner-vpc`, CIDR `10.100.0.0/16` — must
not overlap the app VPC's `10.0.0.0/16`). Because saas test/prod have **private-only**
EKS endpoints, `modules/runner-peering` connects the two so the kubectl layers
(`45-rbac`, `50-addons-helm`) and the `cluster-bootstrap` workflow can reach the API:

1. a VPC peering connection (same account/region, auto-accepted),
2. routes in **both** VPCs (runner → app CIDR, app → runner CIDR),
3. a **443 ingress** on the cluster security group from the runner CIDR,
4. association of the **EKS private hosted zone** with the runner VPC, so the API FQDN
   resolves to the private ENIs from the runner side.

If EKS named its private hosted zone differently from the endpoint FQDN, set
`eks_private_zone_name`; to manage that DNS yourself, set
`associate_eks_private_zone = false`.

---

## Prerequisites

- For `bootstrap`: none.
- For `runner`: `bootstrap`, `00-network`, `10-platform` applied.
- For `45-rbac`: `10-platform` + `bootstrap` applied. No human cluster-admin is
  needed: `10-platform` grants the gated `cluster-bootstrap` role a cluster-admin
  access entry at platform time (`cluster_admin_principal_arns`, wired from
  `bootstrap`), and `include_caller_as_cluster_admin = false` keeps the `tf-apply`
  caller off admin. So `45-rbac` is first-applied **by the gated role via the
  `cluster-bootstrap` workflow** (`scope: full-layer`), not from a laptop.
- The **`SAAS-infra-bot` GitHub App** with repo `administration: write`, installed on the
  infra repo. Its id + installation id (not secret) are passed to the `runner` apply via
  env; its private key (PEM) is seeded once into Secrets Manager after the apply. The
  runner mints short-lived registration tokens from the App — no user PAT.
- For the **out-of-band app secrets** (step 2): a SOPS **age** key (public line in
  `.sops.yaml`) and a `secrets.<env>.enc.env` holding the `TF_VAR_*` values. See the main
  README [Secrets](../README.md#secrets--no-secret-is-passed-from-cigithub) section.

---

## One-time procedure (per env)

```bash
# 1. CI identity first (no deps)
make apply ENV=test LAYER=bootstrap

#    Build + push the per-env toolchain image:
#    GitHub ▸ Actions ▸ bootstrap-image ▸ Run (environment: test)
#    Wire repo/Environment from `cd live/test/bootstrap && terragrunt output`:
#      secret AWS_DEPLOY_ROLE_ARN        = gha_tf_apply_role_arn
#      var    AWS_ROLE_CLUSTER_BOOTSTRAP = gha_cluster_bootstrap_role_arn
#      var    BOOTSTRAP_IMAGE            = toolchain_repository_url

# 2. Seed the out-of-band app secrets (only needs step 1: AWS creds + Secrets
#    Manager). Decrypts secrets.test.enc.env (SOPS/age) and writes stripe/auth-jwt/
#    opensearch/auth0/llm/backstage-input. MUST run before 30-edge (auth0) and
#    40-observability (opensearch) in step 4. See the main README "Secrets" section.
./scripts/seed-secrets.sh test

# 3. Core infra
make apply ENV=test LAYER=00-network
make apply ENV=test LAYER=10-platform

# 4. The runner (own VPC, peered to the app VPC), then register it.
#    GitHub App id/installation are not secret -> supplied via env for the apply.
export GHA_RUNNER_APP_ID=<app-id>
export GHA_RUNNER_APP_INSTALLATION_ID=<installation-id>
make apply ENV=test LAYER=runner
# Seed the App private key (PEM) ONCE + cycle the ASG (key goes to Secrets
# Manager, never Terraform state); the host mints registration tokens from it.
make register-runner ENV=test KEY=app-private-key.pem

# 5. Cluster wiring — first-applied by the gated role via the workflow:
#    GitHub ▸ Actions ▸ cluster-bootstrap ▸ Run (environment: test, scope: full-layer)
#    (This runs on the in-VPC self-hosted runner from step 4, so it reaches the
#     private EKS API; the protected-Environment approval is the only human action.)
```

> **Why the workflow, not `make apply`?** The ci-deployer RBAC holds `bind`/`escalate`,
> so first creation needs a cluster-admin. The gated `cluster-bootstrap` role already
> holds that (granted at `10-platform` time via `cluster_admin_principal_arns`), so
> [`cluster-bootstrap.yml`](../.github/workflows/cluster-bootstrap.yml) with
> `scope: full-layer` applies the entire layer as that role — no human on the cluster.
> `scope: rbac-only` (the default) later re-applies just `-target=module.ci_deployer_rbac`
> for idempotent recovery. A manual `make apply ENV=<env> LAYER=45-rbac` remains a
> break-glass path for an operator who already holds cluster-admin.

---

## Multi-env in one AWS account: the OIDC provider (pre-wired)

There can be only **one** GitHub OIDC provider per account. These three envs share an
account (one state bucket), so it is already wired:

- **`dev`** owns it — `create_oidc_provider = true`.
- **`test` / `prod`** set `create_oidc_provider = false`. The provider ARN is
  **auto-derived** from the account id (the provider URL is fixed), so there is nothing
  to copy between envs.

The only ordering rule: **apply `dev`'s bootstrap before `test`/`prod`'s**, because IAM
validates the federated provider exists when their roles are created.

> If dev/test/prod are actually **separate accounts**, each needs its own provider —
> set `create_oidc_provider = true` in all three.

---

## Staging toggles (`45-rbac`)

- `create_gated_admin_access_entry` (default **`false`**) — create the `cluster-bootstrap`
  → cluster-admin access entry **here**. Off by default because `10-platform` now creates
  it (via `cluster_admin_principal_arns`); set `true` only if platform does not wire the
  gated role, to avoid a duplicate access-entry conflict.
- `map_deployer_access_entry` (default `true`) — the `tf-apply` → `ci-deployers` group entry.
- `manage_ci_deployer_rbac` (default `true`) — apply the escalation-capable ci-deployer ClusterRole.

---

## After bootstrap

- Steady-state `infra.yml` applies `00-network … 50-addons-helm` via the reusable
  `_apply-layer.yml`, assuming the `tf-apply` role through GitHub OIDC. That role is
  **not** cluster-admin — once `45-rbac` has run it acts cluster-side only as the
  `ci-deployers` group.
- Runner placement: every layer runs on GitHub-hosted runners **except**
  `50-addons-helm`, the one layer with helm/kubectl providers. It passes
  `runs_on: ["self-hosted", "vpc"]` + `run_in_toolchain: true` to `_apply-layer.yml`, so it
  runs on the in-VPC runner inside `$${BOOTSTRAP_IMAGE}:<env>` and reaches the **private**
  EKS API — no public endpoint needed in any env.
- `cluster-bootstrap.yml` is the gated path into `45-rbac`: `scope: full-layer` for the
  initial apply, `scope: rbac-only` for idempotent recovery — both as the gated role on
  the in-VPC runner.
- The last standing cluster-admin is now the **gated `cluster-bootstrap` role only**
  (`include_caller_as_cluster_admin = false` is the default), assumable solely through an
  approved deployment to the protected GitHub Environment.
