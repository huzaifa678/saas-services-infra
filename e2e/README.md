# e2e — Secrets Manager source for the E2E smoke runner

Provisions the `saas/e2e` Secrets Manager secret that External Secrets (eso
mode) materializes into the `saas-e2e-env` Secret the ArgoCD PostSync smoke Job
consumes (CD repo: `e2e/chart`, `appsets/e2e.yaml`).

## What this secret holds

Only the infra-derived Kafka bootstrap:

| property | source |
|----------|--------|
| `kafka_bootstrap` | `20-data` MSK SASL/IAM bootstrap |

The runner reads it via External Secrets (ESO) into `saas-e2e-env`.

## Keycloak client secret — generated in-cluster (no SOPS, no script)

The `saas-e2e` Keycloak client is declared in the CD repo's realm import
(`gitops/infra/keycloak/files/saas-realm.json`). Its **secret is generated and
published in-cluster** by an ArgoCD **PreSync hook** in the e2e chart
(`e2e/chart/templates/keycloak-client-secret.yaml`), mirroring the
`gitops/infra/backstage` secret-generation pattern: a least-privilege Job reads
the Keycloak admin password (resource-scoped `get` on `keycloak-admin-secret`),
reads the `saas-e2e` client secret, and writes `E2E_KEYCLOAK_CLIENT_ID` +
`E2E_KEYCLOAK_CLIENT_SECRET` into the `saas-e2e-kc` Secret the smoke Job
envFroms. The client secret never lives in git, SOPS, or AWS — so there is
**nothing to add to the SOPS env** and **no sync script** to run.

## Apply

```bash
cd live/services/test/e2e
terragrunt apply
```

Runs after `live/test/20-data` (MSK). Staging is the test-equivalent env, so it
lives under `live/services/test/`.

## MSK IAM for the runner

Wired. `20-data` grants the runner MSK produce access via an EKS **Pod Identity**
association — `kafka_clients["saas-e2e"]` (namespace `saas-apps`, SA `saas-e2e`,
topic `billing.usage-charge.created`). Because it's Pod Identity (not IRSA), the
CD chart's ServiceAccount needs **no** `role-arn` annotation; the association
binds by namespace + SA name, so the Job's SA must stay `saas-e2e` in `saas-apps`.
The role ARN is exposed as `msk_client_role_arns["saas-e2e"]` if ever needed.

> The `saas-e2e` entry is producer-only; its `consumer_groups = ["saas-e2e"]`
> exists only because the `msk-iam` module requires a non-empty group resource.

The usage-ETL smoke is active: a Confluent-compatible registry is deployed
(`gitops/infra/schema-registry`, Apicurio ccompat) and the e2e chart sets
`E2E_SCHEMA_REGISTRY_URL` at its in-cluster endpoint, so the producer auto-registers
the schema and the ETL path (billing → usage aggregates) is exercised end to end.
