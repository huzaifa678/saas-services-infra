# Self-hosted runner: registration, the ASG, and the GitHub App

How the in-VPC GitHub Actions runner comes up, registers itself, stays alive, and
rolls — and why it authenticates as the **`SAAS-infra-bot` GitHub App** instead of a
personal access token (PAT).

Code: [`modules/gha-runner`](../modules/gha-runner) (compute + identity),
[`layers/runner`](../layers/runner) (per-env wiring). For where this layer sits in the
overall bring-up see the [setup guide](bootstrap.md).

---

## TL;DR

- The runner is a **single-instance Auto Scaling Group** (`min=max=desired=1`) in the
  private subnet of the isolated runner VPC. The ASG is what makes it **self-healing**.
- At boot the instance **registers itself** with GitHub using a short-lived token it
  derives from the `SAAS-infra-bot` GitHub App — no long-lived runner credential is ever
  stored on the box.
- The only secret is the **App private key**, seeded once into Secrets Manager
  out-of-band. App id and installation id are not secret and are passed as variables.
- One command does the post-apply wiring: `make register-runner ENV=<env> KEY=<pem>`.

---

## Why a GitHub App, not a PAT

Earlier the runner used a user **PAT** with the manage-runners scope. The App is better
on every axis that matters for a long-lived, unattended host:

| | PAT (old) | `SAAS-infra-bot` App (now) |
|---|---|---|
| Scope | the user's whole account scope | just repo `administration: write` |
| Identity | tied to a human; dies when they leave | owned by the org, survives offboarding |
| Expiry | PATs expire → silent re-seed churn | key rotates only when you choose |
| On the host | a long-lived token sits in the secret | only a signing key; tokens are minted fresh, short-lived |

The trade-off is honest: you still seed **one** secret once (the App private key). What
you gain is least-privilege scope, no human coupling, and no expiry treadmill.

---

## What the App needs

Create a GitHub App named **`SAAS-infra-bot`** and install it on the infra repo
(`huzaifa678/saas-services-infra`):

- **Permission:** Repository → *Administration: Read and write* (this is what lets it
  call the runner **registration-token** endpoint). Nothing else.
- From the App you need three things:
  - **App ID** — not secret → passed as `github_app_id`.
  - **Installation ID** — not secret (it's in the installation URL) → `github_app_installation_id`.
  - **Private key (PEM)** — secret → seeded into Secrets Manager once.

---

## The registration flow (what happens at boot)

The instance runs [`user-data.sh.tftpl`](../modules/gha-runner/user-data.sh.tftpl). The
host stays minimal — Docker + git only — because all CI tooling lives in the toolchain
image that jobs run inside via `container:`. Registration is a three-hop token exchange:

```
App private key (Secrets Manager)
  │  sign a ~9-min JWT (RS256), iss = App ID
  ▼
JWT ──POST /app/installations/{installation_id}/access_tokens──▶ installation token
  │
  ▼
installation token ──POST /repos/{owner}/{repo}/actions/runners/registration-token──▶ registration token
  │
  ▼
./config.sh --url …/{owner}/{repo} --token <registration token> --labels "self-hosted,vpc" --unattended --replace
./svc.sh install && ./svc.sh start     # runs as a systemd service
```

Key properties:

- The JWT is signed locally with `openssl`; the private key is read into a shell
  variable and passed to `openssl` via process substitution — it never touches disk.
- `set +x` wraps the secret-handling section and the values are `unset` afterwards, so
  **no key or token lands in the cloud-init log**.
- The registration token is single-use and expires in an hour; the runner only needs it
  to register. After that the runner agent holds its own self-managed credentials.
- `--replace` means a re-registering instance (same name `saas-<env>-vpc`) cleanly takes
  over from a previous one.

The host's IAM instance profile is deliberately thin — it can read **only** the App-key
secret, pull **only** the toolchain repo, and use SSM. It holds **no** deploy or cluster
rights; every AWS action a *job* takes is a separate GitHub OIDC federation into the
scoped roles. See [`modules/gha-runner/main.tf`](../modules/gha-runner/main.tf).

---

## The ASG: self-healing and rolls

The runner is an ASG of exactly one instance
([`main.tf`](../modules/gha-runner/main.tf)):

- **Self-healing.** If the instance dies or fails its health check, the ASG launches a
  replacement. The replacement runs the same user-data, mints a **fresh** registration
  token from the App, and re-registers — no human action, no stored token to expire.
- **Rolling on change.** The ASG has an `instance_refresh` (rolling,
  `min_healthy_percentage = 0`). When the **launch template** changes — a new user-data
  script, a bumped `runner_version`, a new AMI — a `terraform apply` triggers the refresh
  and the instance re-registers on the new template. (Seeding the secret does **not**
  change the launch template, so it does not auto-refresh — that's why registration cycles
  the ASG explicitly; see below.)
- **Hardening.** IMDSv2 required (`http_tokens = required`), hop limit 2 so a
  containerized job can still reach IMDS for the instance role; root volume encrypted with
  the runner CMK; security group is egress-only.

---

## Seeding and cycling: `make register-runner`

Terraform creates the secret **empty** on purpose, so no credential is ever committed or
written to Terraform state. Two post-apply actions remain, folded into one target:

```bash
export GHA_RUNNER_APP_ID=<app-id>
export GHA_RUNNER_APP_INSTALLATION_ID=<installation-id>
make apply ENV=<env> LAYER=runner

make register-runner ENV=<env> KEY=app-private-key.pem
```

`register-runner` ([`Makefile`](../Makefile)):

1. `aws secretsmanager put-secret-value` — reads the PEM straight into the
   `runner_app_key_secret_arn` secret (never into Terraform state).
2. `aws autoscaling start-instance-refresh` — cycles the ASG so the fresh instance boots,
   reads the key, and registers.

It guards against a missing/of-nonexistent `KEY` and resolves the secret ARN and ASG name
from the layer's Terraform outputs.

---

## Rotating the App key

1. Generate a new private key for `SAAS-infra-bot` in GitHub (keep the old one until the
   new runner is up).
2. `make register-runner ENV=<env> KEY=new-key.pem` — seeds the new PEM and cycles the ASG.
3. Confirm the runner re-registered (GitHub ▸ repo ▸ Settings ▸ Actions ▸ Runners), then
   delete the old key in GitHub.

Because the stored secret is only a **signing key** (not a live token), there is no token
expiry to chase between rotations.

---

## Troubleshooting

| Symptom | Likely cause | Where to look |
|---|---|---|
| Runner never appears in GitHub | App key secret still empty, or wrong installation id | cloud-init log on the instance (via SSM), `register-runner` output |
| `config.sh` fails with 403 | App lacks `administration: write`, or not installed on the repo | GitHub App settings |
| Jobs queue but never start | Runner labels don't match `runs-on` | registered labels are `self-hosted,vpc` |
| New instance keeps the old config | launch template unchanged; refresh not triggered | re-run `register-runner` (it forces an instance refresh) |

Access the instance through **SSM Session Manager** (the instance profile includes
`AmazonSSMManagedInstanceCore`); the box has no inbound SG rules.
