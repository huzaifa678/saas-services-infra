locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.environment
}

terraform {
  source = "${get_repo_root()}//api-gateway"
}

# Reaches across into the platform tree (live/<env>/20-data) in the same env.
dependency "data" {
  config_path                             = "../../../${local.env}/20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    redis_endpoint = "mock.cache.amazonaws.com"
  }
}

inputs = {
  redis_endpoint = dependency.data.outputs.redis_endpoint
}
