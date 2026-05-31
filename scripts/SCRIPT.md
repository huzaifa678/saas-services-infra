# `verify-apply.sh` — pre-apply verification

Exhaustive pre-flight check for `terraform apply` across one or more
environments. Designed to surface the failure modes that `terraform plan` alone
cannot — destructive replacements, IAM name collisions, and apply-time IAM
errors — without spending money.

Used primarily to validate the **IRSA → EKS Pod Identity** migration introduced
alongside the EKS managed add-ons, but it generalises to any change in this
repo.

---

## What it does

| Step | Check | What it catches |
| --- | --- | --- |
| 1 | `terraform init -reconfigure` with the env's `backend.hcl` | Backend / provider mismatch |
| 2 | `terraform fmt -check -recursive` + `terraform validate` | Style drift, syntax errors, bad references |
| 3 | `terraform plan -detailed-exitcode -out=.tfplan.<env>` | Plan-time provider / schema errors per env |
| 4 | `jq` over the plan JSON for `delete` / `replace` actions | Anything getting destroyed or recreated — **the IRSA → Pod Identity trust swap must be in-place; anything else is a red flag** |
| 4b | Lists all `create` / `update` actions; flags any address outside the expected Pod Identity migration scope | Unintended drift bundled into your PR |
| 5 | `aws iam get-role` for every new `aws_iam_role` resource | Role-name collisions before apply hits AWS |
| 6 | `terraform apply -target=module.iam` (with confirmation prompt) | Real apply-time IAM errors (bad trust JSON, oversized policy, invalid ARN) — still $0 because IAM has no charge |

Step 6 is the closest thing to a "no-cost real apply" check: it actually invokes
the AWS IAM API surface that the full apply would use, but only against
resources that are free to create.

---

## Usage

```bash
# default — runs dev and test
scripts/verify-apply.sh

# explicit env(s)
scripts/verify-apply.sh dev
scripts/verify-apply.sh dev test prod

# plan-only mode — no AWS writes at all (skips step 6)
APPLY_IAM=0 scripts/verify-apply.sh
```

Run from any directory; the script `cd`s to the repo root itself.

---

## Requirements

- `terraform` (>= 1.3 to match `required_version` in `provider.tf`)
- `jq`
- `awscli` v2, authenticated against the target AWS account
- Bash 4+

---

## Environments

The script is parameterised — pass any directory name that exists under
`environments/`. Currently this repo defines:

- `environments/dev/`
- `environments/test/` (acts as the staging tier — there is no `staging/` dir)
- `environments/prod/`

Each must contain both `backend.hcl` and `terraform.tfvars`. If either is
missing the env is skipped with a clear error and the script exits non-zero.

The **default** is `dev` only — it's the only env with a checked-in
`secrets.dev.env`. To run others, pass them explicitly and make sure the
matching `secrets.<env>.env` exists at the repo root.

## Sensitive variables

Variables marked `sensitive = true` in the root (DB passwords, OpenSearch
master password, OpenAI key, etc.) are **not** stored in `terraform.tfvars`.
They live in `secrets.<env>.env` at the repo root, as `export TF_VAR_…=…`
lines. The script auto-sources the matching file before running `plan` /
`apply`. The exports stay scoped to the script's subshell — they do not leak
into your interactive shell.

If `secrets.<env>.env` is missing the script prints a warning and continues;
the plan step will then fail with `No value for required variable` for any
sensitive var the env needs.

---

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Every env passed every check; safe to run `terraform apply` |
| 1 | One or more checks failed — output identifies which env and which step |

Failures that cause exit 1:

- Missing `backend.hcl` / `terraform.tfvars`
- `fmt` drift
- `plan` errors (not no-op — exit code 1 from terraform, not 2)
- Any `delete` or `replace` action in the plan
- IAM role-name collision with an existing role in the target account

---

## What "destructive change" means here

The Pod Identity migration changes the **trust policy** of five existing IAM
roles (cert-manager, external-dns, external-secrets, aws-lb-controller,
karpenter). AWS supports updating `AssumeRolePolicyDocument` in place — no
replacement required.

If the plan shows any of those roles being **replaced** instead of **updated**,
something has drifted (probably an unrelated change to `name`, `path`, or
similar) and you must investigate before applying — replacement would briefly
drop the role, breaking everything bound to it.

---

## Recommended workflow

1. Open a PR with the infra change.
2. Run `scripts/verify-apply.sh dev test` locally (or in CI).
3. Read the green/red summary at the end.
4. If green, run `terraform apply -var-file=environments/<env>/terraform.tfvars`
   from the env you want to ship to first (usually `dev`).
5. Trigger the GitOps refresh: `argocd app sync pod-identity-refresh`
   (see `infra/base/pod-identity-refresh/` in the gitops repo).
6. Promote to `test`, then `prod`, repeating steps 4–5.
