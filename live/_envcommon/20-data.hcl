terraform {
  source = "${get_repo_root()}//layers/20-data"
}

dependency "network" {
  config_path                             = "../00-network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    cluster_name    = "saas-eks-mock"
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock-a", "subnet-mock-b"]
    kms_key_arn     = "arn:aws:kms:us-east-1:000000000000:key/mock"
  }
}

dependency "platform" {
  config_path                             = "../10-platform"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    eks_nodes_sg_id = "sg-mock"
  }
}

inputs = {
  cluster_name    = dependency.network.outputs.cluster_name
  vpc_id          = dependency.network.outputs.vpc_id
  private_subnets = dependency.network.outputs.private_subnets
  kms_key_arn     = dependency.network.outputs.kms_key_arn
  eks_nodes_sg_id = dependency.platform.outputs.eks_nodes_sg_id
}
