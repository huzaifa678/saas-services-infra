# The `_apply-layer` reusable workflow

[`.github/workflows/_apply-layer.yml`](../.github/workflows/_apply-layer.yml) is the
single building block that applies **exactly one layer in one environment,
non-interactively**. [`infra.yml`](../.github/workflows/infra.yml) calls it once per layer
so each layer is its own isolated, independently re-runnable job — instead of one
monolithic apply. This doc explains every part and how the pieces fit.

---

## Why a reusable workflow

- **Isolation / re-runnability** — if `30-edge` fails, you re-run just that job; the
  others are untouched.
- **One definition, many callers** — the apply recipe (OIDC auth → tooling → `make
  apply`) lives once here. `infra.yml` wires the dependency order; this file knows how to
  apply *a* layer.
- **Per-layer overrides without branching logic** — the cluster-facing layer needs a
  different runner and the data layer needs an extra publish step. Both are expressed as
  **inputs**, not forked workflows.

It is a `workflow_call` workflow: it cannot be dispatched directly, only called by another
workflow (today, `infra.yml`).

---

## Inputs

| Input | Type | Default | Purpose |
|---|---|---|---|
| `environment` | string | — (required) | Target env; also selects the GitHub **Environment** (protection + env-scoped secrets/vars) and the Terragrunt unit `live/<env>/<layer>`. |
| `layer` | string | — (required) | Layer directory under `live/<env>/`. |
| `publish_contract` | boolean | `false` | Publish the GitOps contract after apply. Only `20-data` sets this `true`. |
| `runs_on` | string (JSON array) | `'["ubuntu-latest"]'` | Runner labels. The cluster-facing layer overrides to the in-VPC self-hosted runner. |
| `run_in_toolchain` | boolean | `false` | Run the job inside the per-env ECR toolchain image. Needed on the self-hosted runner. |

---

## The job, line by line

```yaml
runs-on: ${{ fromJSON(inputs.runs_on) }}
container: ${{ inputs.run_in_toolchain && fromJSON(format('{{"image":"{0}:{1}"}}', vars.BOOTSTRAP_IMAGE, inputs.environment)) || fromJSON('null') }}
environment: ${{ inputs.environment }}
permissions:
  id-token: write   # OIDC federation into the AWS role
  contents: read    # checkout
```

- **`runs-on`** — `fromJSON` turns the JSON-array string into the labels list. Default is
  GitHub-hosted `ubuntu-latest`; `50-addons-helm` passes `["self-hosted", "vpc"]`.
- **`container`** — when `run_in_toolchain` is true this evaluates to
  `{"image":"<BOOTSTRAP_IMAGE>:<env>"}` so the job runs inside the pinned toolchain image;
  otherwise it is `fromJSON('null')` → **no container** (GitHub skips the container step
  entirely). `vars.BOOTSTRAP_IMAGE` is the toolchain repo URL wired during bootstrap.
- **`environment`** — binds the job to the GitHub Environment, which supplies the env-scoped
  `AWS_DEPLOY_ROLE_ARN` secret and `BOOTSTRAP_IMAGE` var, and enforces any protection rules.
- **`permissions`** — `id-token: write` is what lets `configure-aws-credentials` mint an
  OIDC token; the host itself carries no AWS keys.

### Steps

1. **`actions/checkout@v6`** — the repo (Terragrunt/Terraform sources).

2. **`aws-actions/configure-aws-credentials@v6`** — federates GitHub OIDC into
   `secrets.AWS_DEPLOY_ROLE_ARN` (the scoped **`tf-apply`** role) for `us-east-1`. No
   long-lived AWS credentials exist anywhere in CI — the role is assumed per run and the
   session is short-lived. This is the steady-state deployer identity; it is **not**
   cluster-admin (see [setup guide](bootstrap.md)).

3. **`Setup Terragrunt`** — `uses: ./.github/actions/setup-terragrunt`, gated by
   `if: ${{ !inputs.run_in_toolchain }}`. On the GitHub-hosted path it installs the pinned
   Terragrunt/Terraform; inside the toolchain image those are already present, so the step
   is skipped.

4. **`Apply <layer>`** —
   `make apply ENV=<env> LAYER=<layer> TG_ARGS="-auto-approve"`. The `Makefile` resolves the
   unit `live/<env>/<layer>` and runs `terragrunt apply`. Non-interactive by design.

5. **GitOps contract publish** (two steps, both `if: ${{ inputs.publish_contract }}`, so
   `20-data` only). Both read `terragrunt output -json gitops_contract` and publish it for
   the two CD delivery modes — see [gitops-contract.md](gitops-contract.md):
   - **render mode** → `aws ssm put-parameter /saas/<env>/gitops-contract` (SecureString,
     the full contract).
   - **eso mode** → a trimmed identity slice (`cluster`, `registry`, `keycloak_db_host`,
     `redis`, `kafka`…) to Secrets Manager `saas/<env>/infra-contract` (create or update).

     Master DB credentials are **not** copied here — they stay in the per-DB secrets the
     `rds` module creates.

---

## How `infra.yml` calls it

`infra.yml` is the dependency graph. Each layer is a job that `uses:` this workflow and
`needs:` the previous one, with `secrets: inherit` so the env-scoped secrets flow through:

```yaml
l20-data:
  needs: l10-platform
  uses: ./.github/workflows/_apply-layer.yml
  with:
    environment: ${{ inputs.environment }}
    layer: 20-data
    publish_contract: true          # 20-data publishes the contract
  secrets: inherit

l50-addons-helm:
  needs: l40-observability
  uses: ./.github/workflows/_apply-layer.yml
  with:
    environment: ${{ inputs.environment }}
    layer: 50-addons-helm
    runs_on: '["self-hosted", "vpc"]'   # reaches the PRIVATE EKS API
    run_in_toolchain: true
  secrets: inherit
```

The ordered chain is `00-network → 05-ecr → 10-platform → 20-data → 30-edge →
40-observability → 50-addons-helm`. The `if:` guards (`always() && !cancelled() && …`) let
you run the **full** sequence or a **single** layer via the `target` dispatch input.

### Why `50-addons-helm` is special

It is the only `infra.yml` layer with `helm`/`kubectl`/`kubernetes` providers — i.e. the
only one that talks to the Kubernetes API. On a **private** EKS endpoint a GitHub-hosted
runner cannot reach it, so this layer runs on the **in-VPC self-hosted runner** inside the
toolchain image — the same path [`cluster-bootstrap.yml`](../.github/workflows/cluster-bootstrap.yml)
uses. The helm provider shells out to `aws eks get-token`, which the toolchain image's AWS
CLI provides under the assumed `tf-apply` role. Every other layer touches only public AWS
APIs and stays on `ubuntu-latest`.

> Prerequisite: `50-addons-helm` needs `45-rbac` applied first, so the `tf-apply` role is
> mapped to the `ci-deployers` group (its cluster identity). See the
> [setup guide](bootstrap.md) for the full ordering.

---

## What this workflow deliberately does **not** do

- **`bootstrap`, `runner`, `45-rbac`** are not driven here — they are the CI substrate,
  applied out-of-band or via the gated [`cluster-bootstrap.yml`](../.github/workflows/cluster-bootstrap.yml).
  See [setup guide](bootstrap.md).
- **No secrets on the command line** — everything sensitive is an OIDC role assumption or a
  Secrets Manager/SSM read.
- **No interactive approval** — `-auto-approve`; human gating, where wanted, is the GitHub
  Environment protection, not a prompt.
