terraform {
  source = "${get_repo_root()}//layers/runner"
}

# The self-hosted runner lives in its OWN isolated VPC (modules/runner-vpc) and
# is peered to the application VPC so it can reach the private EKS API. It reads:
#   * bootstrap  -> the toolchain ECR repo it pulls the image from
#   * 00-network -> the app VPC it peers with (id, cidr, private route tables)
#   * 10-platform-> the cluster SG (443 ingress) and endpoint (private DNS)
dependency "bootstrap" {
  config_path = "../bootstrap"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    ecr_repository_arn       = "arn:aws:ecr:us-east-1:000000000000:repository/mock-bootstrap-runner"
    toolchain_repository_url = "000000000000.dkr.ecr.us-east-1.amazonaws.com/mock-bootstrap-runner"
  }
}

dependency "network" {
  config_path = "../00-network"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    vpc_id                  = "vpc-mock"
    vpc_cidr                = "10.0.0.0/16"
    private_route_table_ids = ["rtb-mock-a", "rtb-mock-b", "rtb-mock-c"]
  }
}

dependency "platform" {
  config_path = "../10-platform"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    cluster_security_group_id = "sg-mock"
    cluster_endpoint          = "https://mock.eks.amazonaws.com"
  }
}

inputs = {
  ecr_repository_arn       = dependency.bootstrap.outputs.ecr_repository_arn
  toolchain_repository_url = dependency.bootstrap.outputs.toolchain_repository_url

  app_vpc_id          = dependency.network.outputs.vpc_id
  app_vpc_cidr        = dependency.network.outputs.vpc_cidr
  app_route_table_ids = dependency.network.outputs.private_route_table_ids

  cluster_security_group_id = dependency.platform.outputs.cluster_security_group_id
  cluster_endpoint          = dependency.platform.outputs.cluster_endpoint
}
