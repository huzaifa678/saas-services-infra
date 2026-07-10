# Policy as Code — `saas-services-infra`

Terraform in this repo passes through **three complementary guardrail layers**
before anything reaches AWS. Each catches a different class of problem, and all
three run both in CI (shift-left, on every PR) and in the enforced apply path.

| Layer | Tool | What it catches | Config |
|---|---|---|---|
| **Lint** | [`tflint`](https://github.com/terraform-linters/tflint) + AWS ruleset | Provider misuse, deprecated syntax, invalid instance types, naming, unused declarations | [`.tflint.hcl`](../.tflint.hcl) |
| **Security scan** | [`checkov`](https://www.checkov.io/) | ~1k built-in CIS/AWS benchmarks against the rendered plan, plus five org-specific custom checks | [`.checkov.yaml`](../.checkov.yaml), [`checkov/custom/`](checkov/custom/) |
| **Strict PAC** | [OPA/Rego](https://www.openpolicyagent.org/) via [`conftest`](https://www.conftest.dev/) | **Org-specific** rules on the *plan* — our tag scheme, our admin-port list, our IAM blast-radius rules, the Verified Access exemption | [`opa/`](opa/) |

Why both Checkov **and** Rego? Checkov is a broad, opinionated benchmark library
— great coverage, but generic. The Rego set is small and *ours*: it encodes the
specific contracts this platform must uphold and is evaluated against the
**rendered `terraform plan`**, so it sees the concrete resolved values.

The two enforced sets deliberately overlap. Checkov's `CKV_SAAS_*` custom checks
shadow the Rego `deny` rules one-for-one (unauthenticated MSK, plaintext MSK,
mutable ECR tags, public RDS, unencrypted Redis). One tool failing open must not
let an insecure plan reach AWS.

## Directory layout

```
policy/
├── opa/
│   ├── lib/tfplan.rego          # shared helpers over resource_changes[]
│   ├── terraform/
│   │   ├── security.rego        # deny  (blocking)
│   │   ├── governance.rego      # warn  (advisory)
│   │   └── *_test.rego          # conftest verify — unit tests, no AWS needed
│   └── kubernetes/
│       └── workload.rego        # deny on rendered manifests / helm template output
└── checkov/
    ├── custom/saas_checks.py    # CKV_SAAS_1..5, loaded via external-checks-dir
    └── tests/test_saas_checks.py
```

- **`opa/terraform/security.rego`** — `deny` (blocking). Public RDS, unencrypted
  storage, **MSK unauthenticated access**, non-TLS MSK, unencrypted ElastiCache,
  mutable ECR tags, admin/data ports open to `0.0.0.0/0`, IAM `*:*`. Unambiguous
  defects, so they hard-fail. The single `0.0.0.0/0:443` ingress the Verified
  Access endpoint SG needs is exempted **by tag** (`*-ava-endpoint-sg`), never by
  disabling the rule.
- **`opa/terraform/governance.rego`** — `warn` (advisory). Deletion protection,
  Multi-AZ, `skip_final_snapshot`, tag hygiene. Reported, non-blocking; promoted
  to `deny` once the fleet is clean.
- **`opa/kubernetes/workload.rego`** — `deny` on rendered Kubernetes manifests.
  Runs-as-root, privileged containers, missing resource limits, etc. Charts are
  never trusted at face value.

## Run it locally

```bash
make policy-test    # conftest verify + checkov unit tests — hermetic, no cloud
make opa-test       # just the Rego unit tests
make checkov-test   # just the custom-check unit tests
make policy LAYER=20-data ENV=prod   # full gate: plan -> show -json -> conftest + checkov
```

`make policy` needs a real plan, so it needs AWS access + backend config. The
`*-test` targets are hermetic and run in CI on every PR.

## Handling a violation

- **`deny` / `CKV_SAAS_*`** — fix the Terraform. A legitimate, reviewed exception
  must be a narrow, commented carve-out in the rule (e.g. the AVA tag exemption in
  `security.rego`), never a blanket disable of the whole rule.
- **`warn`** — address it or note it in the PR; it will not block the merge.
