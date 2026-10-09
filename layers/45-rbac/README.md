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

## First apply needs cluster-admin

Kubernetes escalation-prevention: creating a ClusterRole that itself holds
`bind`/`escalate` requires a caller who already has those verbs. So the **first** apply
must run as a cluster-admin — the human bootstrapper (`include_caller_as_cluster_admin
= true` on the platform EKS module) or the gated `cluster-bootstrap` role. After it
exists, the `tf-apply` role reconciles forever as the `ci-deployers` group, never admin.

```bash
# After 10-platform and bootstrap are applied:
make apply ENV=<env> LAYER=45-rbac
```

The [`cluster-bootstrap.yml`](../../.github/workflows/cluster-bootstrap.yml) workflow
re-applies just the RBAC (`-target=module.ci_deployer_rbac`) as the gated role, for
idempotent recovery without a human on Verified Access.

## Staging toggles (all default `true`)

- `create_gated_admin_access_entry` — the `cluster-bootstrap` → cluster-admin entry.
- `map_deployer_access_entry` — the `tf-apply` → `ci-deployers` group entry.
- `manage_ci_deployer_rbac` — apply the escalation-capable ci-deployer ClusterRole.
