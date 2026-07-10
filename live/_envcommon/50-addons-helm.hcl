terraform {
  source = "${get_repo_root()}//layers/50-addons-helm"
}

dependency "network" {
  config_path                             = "../00-network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    vpc_id = "vpc-mock"
  }
}

dependency "platform" {
  config_path                             = "../10-platform"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    cluster_name                      = "saas-eks-mock"
    cluster_endpoint                  = "https://mock.eks.amazonaws.com"
    cluster_ca                        = "TU9DSw=="
    eks_node_group                    = {}
    karpenter_interruption_queue_name = "saas-eks-mock-karpenter"
  }
}

dependency "data" {
  config_path                             = "../20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    keycloak_db_endpoint = "mock.rds.amazonaws.com:5432"
  }
}

dependency "observability" {
  config_path                             = "../40-observability"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs = {
    otel_collector_irsa_role_arn = "arn:aws:iam::000000000000:role/mock"
    prometheus_endpoint          = "https://mock.aps.amazonaws.com"
    opensearch_endpoint          = "mock.es.amazonaws.com"
  }
}

inputs = {
  vpc_id                            = dependency.network.outputs.vpc_id
  cluster_name                      = dependency.platform.outputs.cluster_name
  cluster_endpoint                  = dependency.platform.outputs.cluster_endpoint
  cluster_ca                        = dependency.platform.outputs.cluster_ca
  eks_node_group                    = dependency.platform.outputs.eks_node_group
  karpenter_interruption_queue_name = dependency.platform.outputs.karpenter_interruption_queue_name
  keycloak_db_endpoint              = dependency.data.outputs.keycloak_db_endpoint
  otel_collector_irsa_role_arn      = dependency.observability.outputs.otel_collector_irsa_role_arn
  prometheus_endpoint               = dependency.observability.outputs.prometheus_endpoint
  opensearch_endpoint               = dependency.observability.outputs.opensearch_endpoint
}
