terraform {
  source = "${get_repo_root()}//layers/40-observability"
}

dependency "network" {
  config_path                             = "../00-network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    private_subnets = ["subnet-mock-a", "subnet-mock-b"]
  }
}

dependency "platform" {
  config_path                             = "../10-platform"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/mock"
    oidc_issuer       = "https://oidc.eks.us-east-1.amazonaws.com/id/MOCK"
  }
}

dependency "data" {
  config_path                             = "../20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    opensearch_sg_id = "sg-mock"
  }
}

inputs = {
  private_subnets   = dependency.network.outputs.private_subnets
  oidc_provider_arn = dependency.platform.outputs.oidc_provider_arn
  oidc_issuer       = dependency.platform.outputs.oidc_issuer
  opensearch_sg_id  = dependency.data.outputs.opensearch_sg_id
}
