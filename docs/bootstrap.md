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
- For `45-rbac`: `10-platform` + `bootstrap` applied, and you hold cluster-admin on
  first apply (the platform module's `include_caller_as_cluster_admin = true`).
- A GitHub PAT with the manage-runners scope (seeded after the `runner` apply).

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

# 2. Core infra
make apply ENV=test LAYER=00-network
make apply ENV=test LAYER=10-platform

# 3. The runner (own VPC, peered to the app VPC), then register it
make apply ENV=test LAYER=runner
cd live/test/runner
aws secretsmanager put-secret-value \
  --secret-id "$(terragrunt output -raw runner_pat_secret_arn)" \
  --secret-string "<github-pat>"
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$(terragrunt output -raw runner_asg_name)"
cd -

# 4. Cluster wiring (needs cluster-admin on first apply — see note)
make apply ENV=test LAYER=45-rbac
```

> **Step 4 needs cluster-admin on first apply** (the ci-deployer RBAC holds
> `bind`/`escalate`). Run it as the human bootstrapper or the gated `cluster-bootstrap`
> role. Thereafter [`cluster-bootstrap.yml`](../.github/workflows/cluster-bootstrap.yml)
> re-applies `-target=module.ci_deployer_rbac` in `45-rbac` as the gated role.

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

## Staging toggles (`45-rbac`, all default `true`)

- `create_gated_admin_access_entry` — the `cluster-bootstrap` → cluster-admin access entry.
- `map_deployer_access_entry` — the `tf-apply` → `ci-deployers` group access entry.
- `manage_ci_deployer_rbac` — apply the escalation-capable ci-deployer ClusterRole.

---

## After bootstrap

- Steady-state `infra.yml` runs on `runs-on: [self-hosted, vpc]` inside
  `${BOOTSTRAP_IMAGE}:<env>`, assuming the `tf-apply` role (the `ci-deployers` group).
- `cluster-bootstrap.yml` re-applies just the RBAC in `45-rbac` as the gated admin.
- Once every deploy path uses the `tf-apply` role, flip the platform EKS module's
  `include_caller_as_cluster_admin = false` to remove the last standing cluster-admin.
