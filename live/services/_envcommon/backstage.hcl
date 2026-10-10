locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.environment

  cd_env = local.env == "test" ? "staging" : local.env
}

terraform {
  source = "${get_repo_root()}//backstage"
}

inputs = {
  keycloak_host = local.cd_env == "prod" ? "keycloak.freeeasycrypto.com" : "keycloak.${local.cd_env}.freeeasycrypto.com"
}
