ENV      ?= test
SERVICES := api-gateway auth-service billing-service subscription-service

ENV_DIR         := environments/$(ENV)
BACKEND_CONFIG  := $(ENV_DIR)/backend.hcl
TFVARS          := $(ENV_DIR)/terraform.tfvars

.PHONY: fmt validate init plan apply \
        $(SERVICES:%=init-%) $(SERVICES:%=plan-%) \
        $(SERVICES:%=validate-%) $(SERVICES:%=apply-%)

fmt:
	terraform fmt -recursive

validate: init
	terraform validate

init:
	terraform init -reconfigure -backend-config=$(BACKEND_CONFIG)

plan: init
	terraform plan -var-file=$(TFVARS)

apply: init
	terraform apply -var-file=$(TFVARS)


# Usage: To make init-auth-service ENV=prod
init-%:
	terraform -chdir=$* init -reconfigure \
	  -backend-config=environments/$(ENV)/backend.hcl

validate-%: init-%
	terraform -chdir=$* validate

plan-%: init-%
	terraform -chdir=$* plan \
	  -var-file=environments/$(ENV)/terraform.tfvars

apply-%: init-%
	terraform -chdir=$* apply \
	  -var-file=environments/$(ENV)/terraform.tfvars
