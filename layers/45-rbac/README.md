# 45-rbac layer

Wires the CI identities created by [`bootstrap`](../bootstrap) **into the cluster**.
Split out from `bootstrap` because these resources need the live EKS cluster
(`10-platform`), whereas `bootstrap` (ECR/OIDC/runner) needs only `00-network`.

## What it manages

| Resource | Purpose |
|----------|---------|
| `aws_eks_access_entry.cluster_bootstrap` + admin policy association | The gated `cluster-bootstrap` role → **cluster-admin**. The only cluster-admin principal besides the human bootstrapper. |
| `aws_eks_access_entry.deployer` | The `tf-apply` role → STANDARD entry mapped to the `ci-deployers` Kubernetes group. |
| `modules/ci-deployer-rbac` | The escalation-capable (`bind`/`escalate`) ClusterRole the deployer runs as. **Not** cluster-admin. |

## Dependencies

- **`10-platform`** → `cluster_name`, `cluster_endpoint`, `cluster_ca` (the `kubectl`
  provider and the access entries).
- **`bootstrap`** → `gha_cluster_bootstrap_role_arn`, `gha_tf_apply_role_arn`.

## First apply needs cluster-admin — supplied by the gated role, not a human

Kubernetes escalation-prevention: creating a ClusterRole that itself holds
`bind`/`escalate` requires a caller who already has those verbs. So the **first** apply
must run as a cluster-admin. The root-of-trust admin is the gated `cluster-bootstrap`
role, which `10-platform` grants a cluster-admin access entry at platform time (via
`cluster_admin_principal_arns`, wired from the bootstrap layer). The platform applier is
**not** admin (`include_caller_as_cluster_admin = false`), so the steady-state `tf-apply`
role is never implicitly admin — after this layer exists it reconciles forever as the
`ci-deployers` group only.

Because the gated role is already admin before this layer runs, the **preferred** first
apply is the gated workflow with an approved deployment — no human on the cluster:

```
Actions ▸ cluster-bootstrap ▸ Run  (environment: <env>, scope: full-layer)
```

That applies the entire layer (access entries + RBAC) as the gated role. The default
`scope: rbac-only` re-applies just `-target=module.ci_deployer_rbac` for idempotent
recovery. A manual `make apply ENV=<env> LAYER=45-rbac` still works as a break-glass
path for an operator who already holds cluster-admin, but is no longer the normal route.

> Note: with the gated role wired at platform time, `create_gated_admin_access_entry`
> defaults to **false** here so this layer does not create a duplicate access entry.

## Staging toggles (all default `true`)

- `create_gated_admin_access_entry` — the `cluster-bootstrap` → cluster-admin entry.
- `map_deployer_access_entry` — the `tf-apply` → `ci-deployers` group entry.
- `manage_ci_deployer_rbac` — apply the escalation-capable ci-deployer ClusterRole.
