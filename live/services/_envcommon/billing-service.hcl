locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.environment
}

terraform {
  source = "${get_repo_root()}//billing-service"
}

dependency "network" {
  config_path                             = "../../../${local.env}/00-network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    schema_registry_arn = "arn:aws:glue:us-east-1:000000000000:registry/mock"
  }
}

dependency "data" {
  config_path                             = "../../../${local.env}/20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    redis_endpoint        = "mock.cache.amazonaws.com"
    msk_bootstrap_brokers = "b-1.mock:9098,b-2.mock:9098"
    db_secret_arns        = { billing = "arn:aws:secretsmanager:us-east-1:000000000000:secret:mock" }
  }
}

inputs = {
  billing_db_secret_arn   = dependency.data.outputs.db_secret_arns["billing"]
  redis_endpoint          = dependency.data.outputs.redis_endpoint
  kafka_bootstrap_brokers = dependency.data.outputs.msk_bootstrap_brokers
  schema_registry_arn     = dependency.network.outputs.schema_registry_arn
}
