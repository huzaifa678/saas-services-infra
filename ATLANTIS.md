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

The server config is version-controlled at [`atlantis/repos.yaml`](atlantis/repos.yaml)
— apply it on the Atlantis server with `--repo-config=/etc/atlantis/repos.yaml`.
**Replace the `id` regex** with your actual repo path. It defines:

- the repo allow-rules (`apply_requirements: [approved, mergeable]`,
  `allow_custom_workflows: false` — the repo can pick a workflow name but cannot
  inject shell),
- the `env-deploy` workflow (`init → fmt → validate → plan → policy_check → apply`),
- and the **policy checks** (`policies:` block) described below.

`$WORKSPACE`, `$PLANFILE`, and `$SHOWFILE` are injected by Atlantis. Paths are
relative to each project `dir`, so the same workflow serves the root module and
every service.

---

## Policy checks (guardrails)

Atlantis runs [Policy as Code](policy/README.md) natively. With
`--enable-policy-checks`, a **`policy_check` stage runs after every plan**: it
renders the plan to JSON (`show` → `$SHOWFILE`) and evaluates it with
[`conftest`](https://www.conftest.dev/) against the Rego set in
[`policy/terraform/`](policy/terraform/). This is the enforced twin of the
shift-left CI scan ([`.github/workflows/infra-validate.yml`](.github/workflows/infra-validate.yml)),
so the same rules that advise on the PR also **gate the apply**.

```
plan ──▶ show (plan → JSON) ──▶ conftest test  ──▶  deny?  ──▶ apply blocked
                                                     │
                                       policy owner: atlantis approve_policies
```

- A `deny` (public RDS, unencrypted store, world-open admin port, IAM `*:*`)
  **fails the check and blocks apply**.
- Only a **policy owner** (`policies.owners` in `repos.yaml`) can override a
  failing check with the `atlantis approve_policies` comment — this is separate
  from the normal PR `approved` requirement, so relaxing a guardrail is an
  explicit, attributable act.
- `warn` rules (tags, `skip_final_snapshot`, …) surface in the comment but never
  block.

Single source of truth: the Rego lives in this repo under `policy/terraform/`.
Deliver that directory read-only to the Atlantis pod at
`/etc/atlantis/policies/terraform` (git-sync sidecar, projected volume, or baked
image) so the server evaluates exactly what was reviewed in Git. `conftest` must
be on the server `PATH` (bundled in recent Atlantis images).

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

Cost estimation (Infracost):
```
INFRACOST_API_KEY   # free key from `infracost auth login` — self-hosted, no plan data leaves via us
```

> The `terragrunt` plan workflow runs `infracost breakdown` on `$SHOWFILE` after
> every plan and appends the cost table to the plan comment. It is **informational
> only** — the step swallows its own errors (`|| echo …`), so a layer with no
> billable resources (e.g. `50-addons-helm`) or a missing key never blocks a plan
> or apply. `infracost` must be on the server `PATH` (add it to the image if not).

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
   - `--repo-config=/etc/atlantis/repos.yaml` ([`atlantis/repos.yaml`](atlantis/repos.yaml))
   - `--repo-allowlist=github.com/huzaifa678/saas-services-infra`
   - `--enable-policy-checks` (turns on the `policy_check` stage)
   - GitHub token/app + a webhook secret
2. Mount the `TF_VAR_*` secrets into the pod env (External Secrets → envFrom).
3. Mount this repo's `policy/terraform/` read-only at
   `/etc/atlantis/policies/terraform` (git-sync sidecar / projected volume), and
   confirm `conftest` **and `infracost`** are on the pod `PATH`; export
   `INFRACOST_API_KEY` into the pod env (External Secrets → envFrom).
4. Attach the IAM role (IRSA / instance role).
5. Add a GitHub **webhook** → `https://<atlantis-host>/events`, content type
   `application/json`, events: *Pull requests*, *Pushes*, *Issue comments*,
   *Pull request reviews*.
6. Open a no-op PR (e.g. a comment in a `.tf`) and confirm Atlantis plans **and**
   posts a policy-check result.

> Atlantis is **not** an Argo CD `Application` — it reconciles Terraform/AWS, which
> Argo CD cannot do. Keep it separate from your app-of-apps; Argo CD continues to
> own everything inside the cluster (Helm, Crossplane, Istio).
