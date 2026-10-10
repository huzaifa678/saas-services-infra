terraform {
  source = "${get_repo_root()}//layers/10-platform"
}

dependency "network" {
  config_path = "../00-network"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    cluster_name    = "saas-eks-mock"
    vpc_id          = "vpc-mock"
    vpc_cidr        = "10.0.0.0/16"
    private_subnets = ["subnet-mock-a", "subnet-mock-b", "subnet-mock-c"]
    kms_key_arn     = "arn:aws:kms:us-east-1:000000000000:key/mock"
  }
}

# bootstrap is applied first (out-of-band), so the gated cluster-bootstrap role
# already exists by the time platform runs. Wiring it here makes that role the
# explicit root-of-trust cluster-admin — created at platform time, independent of
# 45-rbac — so the gated workflow can first-apply 45-rbac with no human on the
# cluster, and the tf-apply role is never implicitly admin.
dependency "bootstrap" {
  config_path = "../bootstrap"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    gha_cluster_bootstrap_role_arn = "arn:aws:iam::000000000000:role/mock-cluster-bootstrap"
  }
}

inputs = {
  cluster_name    = dependency.network.outputs.cluster_name
  vpc_id          = dependency.network.outputs.vpc_id
  vpc_cidr        = dependency.network.outputs.vpc_cidr
  private_subnets = dependency.network.outputs.private_subnets
  kms_key_arn     = dependency.network.outputs.kms_key_arn

  # Explicit root-of-trust admin; the Terraform caller is intentionally not admin.
  include_caller_as_cluster_admin = false
  cluster_admin_principal_arns    = [dependency.bootstrap.outputs.gha_cluster_bootstrap_role_arn]
}
