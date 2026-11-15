locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.environment
}

terraform {
  source = "${get_repo_root()}//e2e"
}

dependency "data" {
  config_path                             = "../../../${local.env}/20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    msk_bootstrap_brokers_sasl_iam = "b-1.mock:9098,b-2.mock:9098"
  }
}

# e2e_keycloak_client_id / e2e_keycloak_client_secret are supplied as TF_VARs
# from the SOPS-decrypted env (secrets.<env>.enc.env) — Terraform reads them
# automatically, so they are not listed here.
inputs = {
  environment             = local.env
  kafka_bootstrap_brokers = dependency.data.outputs.msk_bootstrap_brokers_sasl_iam
}
