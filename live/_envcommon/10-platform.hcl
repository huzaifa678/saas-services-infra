terraform {
  source = "${get_repo_root()}//layers/10-platform"
}

dependency "network" {
  config_path = "../00-network"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    cluster_name    = "saas-eks-mock"
    vpc_id          = "vpc-mock"
    vpc_cidr        = "10.0.0.0/16"
    private_subnets = ["subnet-mock-a", "subnet-mock-b"]
    kms_key_arn     = "arn:aws:kms:us-east-1:000000000000:key/mock"
  }
}

inputs = {
  cluster_name    = dependency.network.outputs.cluster_name
  vpc_id          = dependency.network.outputs.vpc_id
  vpc_cidr        = dependency.network.outputs.vpc_cidr
  private_subnets = dependency.network.outputs.private_subnets
  kms_key_arn     = dependency.network.outputs.kms_key_arn
}
