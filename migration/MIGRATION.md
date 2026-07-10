# State migration: single root → six layers

## What changed

The infrastructure used to live in **one Terraform root** (`main.tf` + sibling
`.tf` files) wrapped per environment by `environments/{dev,test,prod}`, which
called it as `module "root"`. Every resource therefore had an address prefixed
`module.root.`, and all of an environment's state lived in one object:
`s3://saas-state-bucket-399849/<env>/terraform.tfstate`.

It is now **six layer roots** under `layers/`, each with its own state object:

| Layer | State key | Owns |
|---|---|---|
| `00-network` | `<env>/00-network/terraform.tfstate` | VPC, subnets, NAT, flow logs, shared KMS, ECR, Glue schema registry |
| `10-platform` | `<env>/10-platform/terraform.tfstate` | EKS, IAM, node SG, pod-identity |
| `20-data` | `<env>/20-data/terraform.tfstate` | RDS ×N, ElastiCache, MSK, data-tier SGs |
| `30-edge` | `<env>/30-edge/terraform.tfstate` | Verified Access (test/prod only) |
| `40-observability` | `<env>/40-observability/terraform.tfstate` | Managed Grafana/Prometheus, OpenSearch, collector IAM |
| `50-addons-helm` | `<env>/50-addons-helm/terraform.tfstate` | Helm releases, OTel collector k8s objects |

Because addresses change (`module.root.module.vpc.*` → `module.vpc.*` in a
different state) this is **not** something Terraform reconciles on its own. Left
alone, `terraform apply` on the new layers would try to **create** everything and
**destroy** the old root's resources. The scripts here move existing objects into
the new per-layer states instead, so a post-migration `plan` is a no-op (or shows
only the deliberate fixes listed at the bottom).

## Order matters

Migrate in layer order, and `plan` after each before proceeding:

```
00-network → 10-platform → 20-data → 30-edge → 40-observability → 50-addons-helm
```

Downstream layers read upstream outputs via `terraform_remote_state`, so an
upstream layer must have real state before a downstream layer can plan.

## Procedure per environment

Run for `ENV=dev`, then `test`, then `prod`. **Take a state backup first** — the
whole point of failure recovery is the pre-migration snapshot.

```bash
export ENV=dev
export STATE_BUCKET=saas-state-bucket-399849

# 0. Back up the current combined state.
aws s3 cp "s3://$STATE_BUCKET/$ENV/terraform.tfstate" \
          "migration/backup-$ENV-$(date +%Y%m%d%H%M%S).tfstate"

# 1. Pull one local copy of the old combined state to `mv` out of.
terraform -chdir=migration/_src init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=$ENV/terraform.tfstate" \
  -backend-config="region=us-east-1"

# 2. Init each new layer through Terragrunt (it generates the backend at the
#    correct <env>/<layer> key). The move scripts do this for you via layer_pull.
for L in 00-network 10-platform 20-data 30-edge 40-observability 50-addons-helm; do
  terragrunt init --working-dir live/$ENV/$L --non-interactive
done

# 3. Move resources. See move-*.sh — one script per layer.
ENV=$ENV bash migration/move-00-network.sh
make plan ENV=$ENV LAYER=00-network      # expect: no changes (make plan == terragrunt plan)
ENV=$ENV bash migration/move-10-platform.sh
make plan ENV=$ENV LAYER=10-platform
# … and so on, verifying a clean plan after each.
```

`migration/_src` is a throwaway root whose only job is to hold the old state so
`terraform state mv -state-out=` can pull objects from it. It contains just a
`backend "s3" {}` block and the provider — no resources. The **destination**
layers are Terragrunt-managed (they no longer carry a backend block), so the
move scripts push into them with `terragrunt state push`; the state **keys** are
unchanged (`<env>/<layer>/terraform.tfstate`), so nothing about the target
addresses moved when Terragrunt was introduced.

## Address mapping (source → destination)

Source addresses all carry the `module.root.` prefix from the old
`environments/<env>` wrapper. Destination is the new layer's own state.

### 00-network
| Source (in `<env>/terraform.tfstate`) | Destination (`<env>/00-network/…`) |
|---|---|
| `module.root.module.vpc` (whole module) | `module.vpc` |
| `module.root.aws_kms_key.main` | `aws_kms_key.main` |
| `module.root.aws_kms_alias.main` | `aws_kms_alias.main` |
| `module.root.aws_cloudwatch_log_group.vpc_flow_logs` | `aws_cloudwatch_log_group.vpc_flow_logs` |
| `module.root.aws_iam_role.vpc_flow_log` | `aws_iam_role.vpc_flow_log` |
| `module.root.aws_iam_role_policy.vpc_flow_log` | `aws_iam_role_policy.vpc_flow_log` |
| `module.root.aws_ecr_repository.services["<svc>"]` | `aws_ecr_repository.services["<svc>"]` |
| `module.root.aws_glue_registry.schema_registry` | `aws_glue_registry.schema_registry` |

`aws_kms_key_policy.main` is **new** (the key previously had only the implicit
default policy). It will show as an addition on the first plan — that is expected
and is the fix that lets the flow-log group use the CMK.

### 10-platform
| Source | Destination (`<env>/10-platform/…`) |
|---|---|
| `module.root.module.eks` (whole module) | `module.eks` |
| `module.root.module.iam` (whole module) | `module.iam` |
| `module.root.aws_eks_access_entry.karpenter_node` | `aws_eks_access_entry.karpenter_node` |
| `module.root.aws_eks_pod_identity_association.this[<k>]` | `aws_eks_pod_identity_association.this["<k>"]` |
| `module.root.module.security_group.aws_security_group.eks_nodes` | `module.node_security_group.aws_security_group.eks_nodes` |
| node-SG egress/ingress rules (see note) | `module.node_security_group.aws_vpc_security_group_*` |

> **Node SG rules are re-created, not moved.** The old module used inline
> `egress`/`ingress` blocks and `aws_security_group_rule`; the new module uses
> discrete `aws_vpc_security_group_egress_rule` / `_ingress_rule` resources with
> different addresses and identities. Move the `aws_security_group.eks_nodes`
> shell so the SG id (and its `karpenter.sh/discovery` tag) is preserved, and let
> the rules re-create. They are stateless L4 rules; recreation is non-disruptive.

### 20-data
| Source | Destination (`<env>/20-data/…`) |
|---|---|
| `module.root.module.rds_subscription` | `module.rds["subscription"]` |
| `module.root.module.rds_billing` | `module.rds["billing"]` |
| `module.root.module.rds_usage` | `module.rds["usage"]` |
| `module.root.module.rds_auth[0]` (test only) | `module.rds["auth"]` |
| `module.root.module.rds_keycloak[0]` (dev/prod) | `module.rds["keycloak"]` |
| `module.root.module.elasticache` | `module.elasticache` |
| `module.root.module.msk` | `module.msk` |
| data-tier SGs (`rds_sg`, `redis_sg`, `msk_sg`, `opensearch_sg`) | `module.data_security_groups.aws_security_group.this["<tier>"]` |

> The RDS modules move from **count/named** modules to a **for_each** map, so the
> index changes (`module.rds_billing` → `module.rds["billing"]`). The data-tier
> SGs likewise move to a keyed `for_each`, and their ingress rules re-create (same
> stateless-rule note as the node SG).

### 30-edge (test / prod only)
Verified Access was **broken** in the old code (duplicate endpoint SG, invalid
`network-interface` endpoint). None of it applied cleanly, so there is nothing to
move — the `verified-access` module is a fresh create. If a partial AVA instance
exists in state, import it:
```bash
terraform -chdir=layers/30-edge import 'module.verified_access[0].aws_verifiedaccess_instance.this' <ava-id>
```

### 40-observability
| Source | Destination (`<env>/40-observability/…`) |
|---|---|
| `module.root.module.observability.module.grafana[0]` (grafana envs) | `module.observability.module.grafana[0]` |
| `module.root.module.observability.module.elk[0]` (elk envs) | `module.observability.module.elk[0]` |

> The `module.otel` sub-module does **not** move here. It provisions cluster
> objects and now lives in 50-addons-helm.

### 50-addons-helm
| Source | Destination (`<env>/50-addons-helm/…`) |
|---|---|
| `module.root.module.k8s` (whole module) | `module.k8s` |
| `module.root.module.observability.module.otel` | `module.otel` |

## Deliberate changes that WILL show on the first clean plan

These are the fixes bundled with the restructure. A post-migration plan is not
expected to be empty; it is expected to show *only* these:

1. **`aws_kms_key_policy.main`** — added, so CloudWatch log groups can use the CMK.
2. **MSK** — `client_authentication` flips from `unauthenticated = true` to
   SASL/IAM (+ SASL/SCRAM in prod). **This is a broker-auth change; coordinate
   with clients.** Producers/consumers must present IAM (or SCRAM) credentials
   after apply.
3. **ElastiCache** — an AUTH token is generated and required; `automatic_failover`
   / `multi_az` turn on in test/prod. Clients must present the token.
4. **RDS** — `multi_az`, `deletion_protection`, backup retention and PI now track
   the guardrails matrix; `skip_final_snapshot` can no longer be true alongside
   deletion protection.
5. **Data-tier & node SG rules** — re-created as discrete rule resources; MSK port
   9092 (plaintext) is no longer opened.
6. **Verified Access** — created for the first time (test/prod).

Items 2–3 are client-visible auth changes. Stage them behind a maintenance window.
