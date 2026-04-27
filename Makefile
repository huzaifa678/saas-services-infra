TFVARS     ?= test.tfvars
SERVICES   := api-gateway auth-service billing-service subscription-service

.PHONY: fmt validate plan apply $(SERVICES:%=init-%) $(SERVICES:%=plan-%) $(SERVICES:%=validate-%)

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan:
	terraform plan -var-file=$(TFVARS)

apply:
	terraform apply -var-file=$(TFVARS)

init-%:
	terraform -chdir=$* init

validate-%:
	terraform -chdir=$* validate

plan-%:
	terraform -chdir=$* plan

apply-%:
	terraform -chdir=$* apply
