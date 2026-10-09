locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals.environment
}

terraform {
  source = "${get_repo_root()}//usage-service"
}

dependency "data" {
  config_path                             = "../../../${local.env}/20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    msk_bootstrap_brokers_sasl_iam = "b-1.mock:9098,b-2.mock:9098"
    db_secret_arns                 = { usage = "arn:aws:secretsmanager:us-east-1:000000000000:secret:mock" }
  }
}

inputs = {
  environment             = local.env
  usage_db_secret_arn     = dependency.data.outputs.db_secret_arns["usage"]
  kafka_bootstrap_brokers = dependency.data.outputs.msk_bootstrap_brokers_sasl_iam
}
