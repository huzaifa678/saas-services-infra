terraform {
  source = "${get_repo_root()}//layers/bootstrap"
}

dependency "network" {
  config_path = "../00-network"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-a", "subnet-mock-b", "subnet-mock-c"]
    kms_key_arn     = "arn:aws:kms:us-east-1:000000000000:key/mock"
  }
}

dependency "platform" {
  config_path = "../10-platform"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    cluster_name     = "saas-eks-mock"
    cluster_endpoint = "https://mock.eks.amazonaws.com"
    cluster_ca       = "TU9DSw=="
  }
}

inputs = {
  vpc_id          = dependency.network.outputs.vpc_id
  private_subnets = dependency.network.outputs.private_subnets
  kms_key_arn     = dependency.network.outputs.kms_key_arn

  cluster_name     = dependency.platform.outputs.cluster_name
  cluster_endpoint = dependency.platform.outputs.cluster_endpoint
  cluster_ca       = dependency.platform.outputs.cluster_ca
}
