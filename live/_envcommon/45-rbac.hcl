terraform {
  source = "${get_repo_root()}//layers/45-rbac"
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

dependency "bootstrap" {
  config_path = "../bootstrap"

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    gha_cluster_bootstrap_role_arn = "arn:aws:iam::000000000000:role/mock-cluster-bootstrap"
    gha_tf_apply_role_arn          = "arn:aws:iam::000000000000:role/mock-tf-apply"
  }
}

inputs = {
  cluster_name     = dependency.platform.outputs.cluster_name
  cluster_endpoint = dependency.platform.outputs.cluster_endpoint
  cluster_ca       = dependency.platform.outputs.cluster_ca

  cluster_bootstrap_role_arn = dependency.bootstrap.outputs.gha_cluster_bootstrap_role_arn
  tf_apply_role_arn          = dependency.bootstrap.outputs.gha_tf_apply_role_arn
}
