SHELL       := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ENV        ?= dev
LAYER      ?=
LIVE       := live/$(ENV)
UNIT       := live/$(ENV)/$(LAYER)
LAYERS     := 00-network 10-platform 20-data 30-edge 40-observability 50-addons-helm
MODULES    := guardrails node-security-group data-security-groups verified-access \
              eks iam rds msk elasticache observability k8s-and-helm otel grafana elk
POLICY_DIR := policy

.PHONY: help
help:
	@grep -hE '^[a-zA-Z0-9_.-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

.PHONY: fmt
fmt: 
	terraform fmt -recursive
	terragrunt hcl fmt

.PHONY: fmt-check
fmt-check: 
	terraform fmt -recursive -check -diff
	terragrunt hcl fmt --check --diff

.PHONY: validate
validate: 
	@for m in $(MODULES); do \
	  echo "==> module/$$m"; \
	  terraform -chdir=modules/$$m init -backend=false -input=false >/dev/null; \
	  terraform -chdir=modules/$$m validate; \
	done
	@for l in $(LAYERS); do \
	  echo "==> layer/$$l"; \
	  terraform -chdir=layers/$$l init -backend=false -input=false >/dev/null; \
	  terraform -chdir=layers/$$l validate; \
	done

.PHONY: tg-render
tg-render: ## Resolve every platform unit's config with dependency mocks (no AWS)
	@for env in dev test prod; do \
	  for l in $(LAYERS); do \
	    printf "  %-4s %-18s " "$$env" "$$l"; \
	    terragrunt render --working-dir live/$$env/$$l >/dev/null && echo ok; \
	  done; \
	done

.PHONY: svc-render
svc-render: ## Resolve every service unit's config with dependency mocks (no AWS)
	@for u in $$(find live/services -name terragrunt.hcl -not -path '*/_envcommon/*' | sed 's|/terragrunt.hcl||' | sort); do \
	  printf "  %-30s " "$${u#live/services/}"; \
	  terragrunt render --working-dir $$u >/dev/null && echo ok; \
	done

.PHONY: test-guardrails
test-guardrails: 
	terraform -chdir=modules/guardrails init -backend=false -input=false >/dev/null
	terraform -chdir=modules/guardrails test

.PHONY: opa-fmt-check
opa-fmt-check: 
	conftest fmt --check $(POLICY_DIR)/opa

.PHONY: opa-test
opa-test: 
	conftest verify --policy $(POLICY_DIR)/opa/terraform --policy $(POLICY_DIR)/opa/lib
	conftest verify --policy $(POLICY_DIR)/opa/kubernetes

.PHONY: checkov-test
checkov-test:
	python3 -m pytest $(POLICY_DIR)/checkov/tests -q

.PHONY: policy-test
policy-test: opa-fmt-check opa-test checkov-test ## All hermetic policy tests

.PHONY: plan
plan: 
	@test -n "$(LAYER)" || { echo "LAYER is required, e.g. make plan ENV=prod LAYER=20-data"; exit 1; }
	terragrunt plan --working-dir $(UNIT)

.PHONY: apply
apply: 
	@test -n "$(LAYER)" || { echo "LAYER is required"; exit 1; }
	terragrunt apply --working-dir $(UNIT)

.PHONY: plan-all
plan-all: 
	terragrunt run-all plan --working-dir $(LIVE) --non-interactive

.PHONY: apply-all
apply-all:
	terragrunt run-all apply --working-dir $(LIVE)

# ── Services (separate tree: live/services/<env>/<service>) ───────────────────
.PHONY: svc-plan
svc-plan: ## make svc-plan ENV=test SERVICE=api-gateway
	@test -n "$(SERVICE)" || { echo "SERVICE is required, e.g. make svc-plan ENV=test SERVICE=api-gateway"; exit 1; }
	terragrunt plan --working-dir live/services/$(ENV)/$(SERVICE)

.PHONY: svc-apply
svc-apply: ## make svc-apply ENV=test SERVICE=api-gateway
	@test -n "$(SERVICE)" || { echo "SERVICE is required"; exit 1; }
	terragrunt apply --working-dir live/services/$(ENV)/$(SERVICE)

.PHONY: svc-plan-all
svc-plan-all: ## Plan every service in ENV (dependency mocks fill the platform)
	terragrunt run-all plan --working-dir live/services/$(ENV) --non-interactive

.PHONY: conftest
conftest: 
	@test -n "$(LAYER)" || { echo "LAYER is required"; exit 1; }
	terragrunt plan --working-dir $(UNIT) -out=tfplan.bin
	terragrunt show --working-dir $(UNIT) -json tfplan.bin > $(UNIT)/plan.json
	conftest test $(UNIT)/plan.json \
	  --policy $(POLICY_DIR)/opa/terraform \
	  --policy $(POLICY_DIR)/opa/lib \
	  --namespace terraform.security,terraform.governance \
	  --all-namespaces=false

.PHONY: checkov
checkov:
	@test -n "$(LAYER)" || { echo "LAYER is required"; exit 1; }
	terragrunt plan --working-dir $(UNIT) -out=tfplan.bin
	terragrunt show --working-dir $(UNIT) -json tfplan.bin > $(UNIT)/plan.json
	checkov --config-file .checkov.yaml -f $(UNIT)/plan.json

.PHONY: policy
policy: conftest checkov

# ── Cost estimation (Infracost) ──────────────────────────────────────────────
# Same plan -> show -json -> read plan.json pattern as conftest/checkov, so it
# reuses the mock_outputs wiring and needs no extra state access at estimate time.
# Requires INFRACOST_API_KEY in the environment (get a free key: infracost auth login).
.PHONY: infracost
infracost: ## Cost estimate for one unit: make infracost ENV=prod LAYER=20-data
	@test -n "$(LAYER)" || { echo "LAYER is required, e.g. make infracost ENV=prod LAYER=20-data"; exit 1; }
	terragrunt plan --working-dir $(UNIT) -out=tfplan.bin
	terragrunt show --working-dir $(UNIT) -json tfplan.bin > $(UNIT)/plan.json
	infracost breakdown --path $(UNIT)/plan.json

.PHONY: infracost-all
infracost-all: ## Full cost breakdown for ENV across all cost-bearing layers
	@rm -rf /tmp/infracost && mkdir -p /tmp/infracost
	@for l in 00-network 10-platform 20-data 30-edge 40-observability; do \
	  echo "==> $(ENV)/$$l"; \
	  terragrunt plan --working-dir $(LIVE)/$$l -out=tfplan.bin; \
	  terragrunt show --working-dir $(LIVE)/$$l -json tfplan.bin > $(LIVE)/$$l/plan.json; \
	  infracost breakdown --path $(LIVE)/$$l/plan.json --format json --out-file /tmp/infracost/$$l.json; \
	done
	infracost output --path "/tmp/infracost/*.json" --format table

.PHONY: ci-static
ci-static: fmt-check validate test-guardrails policy-test tg-render svc-render ## Everything hermetic

.PHONY: lint
lint: 
	tflint --init
	tflint --recursive --minimum-failure-severity=error

.PHONY: clean
clean:
	find . -name '.terraform' -type d -prune -exec rm -rf {} + 2>/dev/null || true
	find . -name '.terragrunt-cache' -type d -prune -exec rm -rf {} + 2>/dev/null || true
	find . \( -name 'tfplan.bin' -o -name 'plan.json' \) -delete 2>/dev/null || true
