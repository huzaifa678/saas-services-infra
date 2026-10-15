terraform {
  source = "${get_repo_root()}//layers/40-observability"
}

dependency "network" {
  config_path                             = "../00-network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    private_subnets = ["subnet-mock-a", "subnet-mock-b", "subnet-mock-c"]
  }
}

dependency "platform" {
  config_path                             = "../10-platform"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    cluster_name = "saas-eks-mock"
  }
}

dependency "data" {
  config_path                             = "../20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    opensearch_sg_id = "sg-mock"
  }
}

inputs = {
  private_subnets  = dependency.network.outputs.private_subnets
  cluster_name     = dependency.platform.outputs.cluster_name
  opensearch_sg_id = dependency.data.outputs.opensearch_sg_id
}
