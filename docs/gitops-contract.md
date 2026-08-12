# GitOps Contract

The single machine-readable handoff from this Terraform repo to the CD repo
(`saas-continious-delivery`). The `20-data` layer publishes it as the
`gitops_contract` Terraform output; the CD repo's `scripts/render_gitops.py`
consumes it and renders the Crossplane `provider-sql` blocks and per-app values.

Without this, the CD repo hand-maintains RDS instance names, Secrets Manager
secret names, and endpoints — and they silently drift from what Terraform
actually created. The contract makes Terraform the source of truth.

## Producing it

```bash
cd live/<env>/20-data
terragrunt output -json gitops_contract > gitops-contract.<env>.json
```

CI (Atlantis) exports this after apply and hands it to the CD renderer.

## Schema

```jsonc
{
  "version": 1,
  "cluster": {
    "name": "saas-eks-<env>",                 // EKS cluster name (karpenter/aws-lb clusterName)
    "region": "us-east-1",
    "karpenter_interruption_queue": "saas-eks-<env>-karpenter-interruption"
  },
  "databases": {
    "<instance>": {                 // auth | billing | subscription | usage | keycloak | airflow
      "instance": "<instance>",
      "endpoint": "host:5432",       // RDS endpoint
      "db_name": "<db>",             // master database name
      "username": "<user>",          // master username
      "secret_name": "saas-<svc>-db-secret"  // Secrets Manager secret holding master creds
    }
  },
  "redis": {
    "endpoint": "<primary-endpoint>",
    "port": 6379,
    "auth_secret_arn": "<arn>"
  },
  "kafka": {
    "bootstrap_brokers": "<brokers>"
  }
}
```

## Rules

- `version` is bumped on any breaking shape change; the renderer pins the major.
- `cluster.karpenter_interruption_queue` is `modules/iam`'s
  `${cluster_name}-karpenter-interruption`; the CD renderer injects it (and
  `cluster.name`) into the karpenter/aws-lb addon overlays.
- `databases` keys are exactly the RDS instances Terraform created for the
  environment (conditional ones like `auth`/`keycloak` appear only when active).
- `secret_name` follows `modules/rds` convention `${name}-secret`; the CD
  renderer uses it verbatim as the External Secrets `remoteRef.key`.
- The contract carries no secret *values* — only names/ARNs/endpoints. Master
  credentials stay in Secrets Manager and reach the cluster via External Secrets.
