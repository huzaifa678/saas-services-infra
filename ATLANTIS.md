# Atlantis — PR-based GitOps for `saas-services-infra`

This repo uses [Atlantis](https://www.runatlantis.io/) to drive Terraform from
pull requests. `atlantis.yaml` (repo root) maps every Terraform root + environment
to an Atlantis *project*. The actual `terraform` commands live in the **server-side**
`env-deploy` workflow below, so the repo cannot inject arbitrary shell into the
runner (the secure, enterprise default).

The old manual pipeline (`.github/workflows/infra.yml`, `workflow_dispatch`) is
**kept as a break-glass fallback** — use it only if Atlantis is down.

---

## Why Atlantis (and not the alternatives)

The goal was GitOps for the **Terraform layer**: auto-sync on infra code changes,
with a reviewable plan before anything touches AWS. The key constraint is that
this repo is **Terraform → AWS**, not Kubernetes manifests.

### Why not Argo CD here

Argo CD already owns everything *inside* the cluster (Helm, Crossplane, Istio) and
it's the right tool there. But Argo CD is a **Kubernetes reconciler** — it diffs
desired manifests against a live API server. It has **no `terraform plan/apply`
engine and no concept of AWS state**, so pointing an `Application` at `.tf` files
does nothing. Bringing Terraform "into Argo CD" would mean rewriting infra as
Crossplane CRDs or running Terraform-in-cluster (tf-controller) — dragging state,
cloud creds, and blast radius into the cluster. We deliberately keep the boundary:

```
CI/Atlantis  → Terraform → AWS substrate (VPC, EKS, RDS, ECR, IAM, KMS, OpenSearch)
                                   │ hands off the cluster
Argo CD      → everything inside Kubernetes (Helm, Crossplane DBs, Istio, apps)
```

This is the standard enterprise split: **pipeline for IaC, GitOps controller for
in-cluster state.** Crossplane stays scoped to the self-service database slice
where the CRD model genuinely pays off — it is *not* expanded to all of AWS.

### Comparison

| Tool | Model | Verdict for this repo |
|---|---|---|
| **Atlantis**  | PR-comment-driven TF runner, self-hosted, free | **Chosen.** Plan posted in the PR, gated apply, multi-project/multi-env mapping, reuses our existing GitHub + EKS/IRSA. No vendor lock-in. |
| **HCP Terraform / TF Cloud** | Managed VCS-driven runs, remote state, Sentinel | Solid, but SaaS; we already have S3 state + locking and want to self-host on the cluster we own. |
| **Spacelift / env0 / Scalr** | Atlantis-like + drift, RBAC, nicer UI | Good, but commercial $$ for capabilities we don't yet need. |
| **Argo CD (plain)** | K8s manifest reconciler | Can't run Terraform at all. Wrong layer. |
| **Crossplane / tf-controller** | Cloud-as-CRD, reconciled in-cluster | Would mean a rewrite or Terraform-in-cluster; keeps blast radius/state in the cluster. Crossplane intentionally limited to DBs. |
| **Plain GitHub Actions (push trigger)** | `apply` on merge | Simplest, but weaker UX: no inline plan-in-PR review, no per-project locks, no comment-driven gated apply. Retained only as the fallback below. |

### Why keep `workflow_dispatch` as a fallback

`.github/workflows/infra.yml` is **intentionally not deleted**. It's the
**break-glass path** for when Atlantis itself is unavailable:

- Atlantis server / webhook / cluster outage, or Atlantis misconfiguration.
- An emergency apply needed before Atlantis is (re)deployed.
- Bootstrapping a brand-new environment before Atlantis knows about it.

It runs the identical `init → fmt → validate → plan → apply` against the same
state and the same `AWS_DEPLOY_ROLE_ARN`, so it's a safe manual substitute. Day to
day it stays idle — all routine changes go through Atlantis PRs. If you ever fully
retire it, do so only after Atlantis has owned every project for a release cycle.

---

## How it works (developer flow)

```
open PR ──▶ Atlantis auto-plans each affected project ──▶ plan posted in PR
        ──▶ teammate approves ──▶ comment `atlantis apply` ──▶ merge
```

Useful PR comments:

| Comment | Effect |
|---|---|
| `atlantis plan` | Re-plan all affected projects |
| `atlantis plan -p auth-service-prod` | Plan one project |
| `atlantis apply -p auth-service-prod` | Apply one project (requires approval + mergeable) |
| `atlantis apply` | Apply all planned projects in the PR |
| `atlantis unlock` | Release the PR's project locks |

Apply is **comment-driven and gated** (`apply_requirements: [approved, mergeable]`),
so nothing reaches AWS without a green review and an up-to-date branch.

---

## State isolation (do not skip)

Each environment has its own backend `key` in `environments/<env>/backend.hcl`,
all in the **default** Terraform workspace (matches the `Makefile`). Atlantis must
**not** create a Terraform workspace per env, or state would move to
`env:/<workspace>/<key>`.

The `env-deploy` workflow therefore:
- sets `TF_WORKSPACE=default` (forces the default workspace regardless of the
  Atlantis `workspace:` name), and
- uses `$WORKSPACE` (= the Atlantis workspace = env name) only to pick the
  `-backend-config` and `-var-file`.

The `workspace:` field in `atlantis.yaml` exists purely to namespace Atlantis
locks/plan files per environment within the same directory.

---

## Server-side config (`repos.yaml`)

Apply this on the Atlantis server (`--repo-config=/etc/atlantis/repos.yaml`).
**Replace the `id` regex** with your actual repo path.

```yaml
repos:
  - id: github.com/huzaifa678/saas-services-infra
    apply_requirements: [approved, mergeable]
    allowed_overrides: [workflow]      # lets atlantis.yaml pick `workflow: env-deploy`
    allow_custom_workflows: false      # repo cannot define its own shell steps

workflows:
  env-deploy:
    plan:
      steps:
        - env:
            name: TF_WORKSPACE
            value: default
        - run: terraform init -reconfigure -backend-config=environments/$WORKSPACE/backend.hcl
        - run: terraform fmt -check -recursive
        - run: terraform validate
        - run: terraform plan -input=false -lock-timeout=300s -var-file=environments/$WORKSPACE/terraform.tfvars -out=$PLANFILE
    apply:
      steps:
        - env:
            name: TF_WORKSPACE
            value: default
        - run: terraform apply -input=false -lock-timeout=300s $PLANFILE
```

`$WORKSPACE` and `$PLANFILE` are injected by Atlantis. Paths are relative to each
project `dir`, so the same workflow serves the root module and every service.

---

## Required environment on the Atlantis server

Terraform auto-reads `TF_VAR_*` from the environment. The Atlantis container/pod
must export the same secrets the old workflow injected (sourced from your secrets
manager, e.g. External Secrets — never commit these):

Root + provider:
```
AWS auth via IRSA / instance role (see IAM below) — no static keys
TF_VAR_keycloak_db_password
TF_VAR_subscription_db_password
TF_VAR_billing_db_password
TF_VAR_usage_db_password
TF_VAR_opensearch_master_password
TF_VAR_openai_api_key
TF_VAR_ava_oidc_client_id
TF_VAR_ava_oidc_client_secret
```

Service modules:
```
TF_VAR_auth_jwt_secret
TF_VAR_auth_jwt_refresh_secret
TF_VAR_keycloak_jwks_url
TF_VAR_gateway_jwt_secret
TF_VAR_stripe_api_key
```

> All projects share one server env, so plans/applies see every `TF_VAR_*`.
> Terraform ignores ones a given module doesn't declare.

---

## AWS access

Give the Atlantis runtime the same permissions as `AWS_DEPLOY_ROLE_ARN`:
- **On EKS:** an IRSA service account annotated with that role (you already use
  IRSA for karpenter/external-dns/etc.), or
- **On EC2/ECS:** an instance/task role.

Region is `us-east-1`. State bucket: `saas-state-bucket-399849` (S3 native locking
via `use_lockfile = true`).

---

## Deploy checklist

1. Run Atlantis (Helm chart `runatlantis/atlantis`, ECS, or EC2) with:
   - `--repo-config=/etc/atlantis/repos.yaml` (the file above)
   - `--repo-allowlist=github.com/huzaifa678/saas-services-infra`
   - GitHub token/app + a webhook secret
2. Mount the `TF_VAR_*` secrets into the pod env (External Secrets → envFrom).
3. Attach the IAM role (IRSA / instance role).
4. Add a GitHub **webhook** → `https://<atlantis-host>/events`, content type
   `application/json`, events: *Pull requests*, *Pushes*, *Issue comments*,
   *Pull request reviews*.
5. Open a no-op PR (e.g. a comment in a `.tf`) and confirm Atlantis plans.

> Atlantis is **not** an Argo CD `Application` — it reconciles Terraform/AWS, which
> Argo CD cannot do. Keep it separate from your app-of-apps; Argo CD continues to
> own everything inside the cluster (Helm, Crossplane, Istio).
