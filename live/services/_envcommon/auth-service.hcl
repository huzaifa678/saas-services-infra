locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.environment
}

terraform {
  source = "${get_repo_root()}//auth-service"
}

# auth-service is only deployed where the platform's auth_provider is
# "auth-service" (test). In keycloak envs (prod) there is no auth DB to read.
dependency "data" {
  config_path                             = "../../../${local.env}/20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    db_secret_arns = { auth = "arn:aws:secretsmanager:us-east-1:000000000000:secret:mock" }
  }
}

inputs = {
  auth_db_secret_arn = dependency.data.outputs.db_secret_arns["auth"]
}
