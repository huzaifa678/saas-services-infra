terraform {
  source = "${get_repo_root()}//layers/50-addons-helm"
}

dependency "network" {
  config_path                             = "../00-network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    vpc_id = "vpc-mock"
  }
}

dependency "platform" {
  config_path                             = "../10-platform"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    cluster_name                      = "saas-eks-mock"
    cluster_endpoint                  = "https://mock.eks.amazonaws.com"
    cluster_ca                        = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNtakNDQVlJQ0NRREQ1Q3VUeDhweHh6QU5CZ2txaGtpRzl3MEJBUXNGQURBUE1RMHdDd1lEVlFRRERBUnQKYjJOck1CNFhEVEkyTURnd09ERXdNakExTVZvWERUTTJNRGd3TlRFd01qQTFNVm93RHpFTk1Bc0dBMVVFQXd3RQpiVzlqYXpDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTU5ySy81c2dIZGZCS1d4CnAvSS91OUxTMlhMeldGKzJ0cW54c2t3b2xvU2pBcE5RU1gvcnR2TkNaVWFPSThISGhRbEhOZjhmSXBYUXhVMHIKZ1JFcFRqTUIvUWdWZ0NmbnRJeTdzYkxQNHdlWDVITG52c3VPSW12N2hNeXdvdEV4Ui90QldLcVJ6UmdxZUNlaQowa29IeHI5T1hrVzRVc0pYcklmWUNwY0g0NEVTTmFReE1ZTzVBNW0raW1Gd054SFQvNk8wZC9zK01wbGRVUEs3CnlVemoxejBaMXhJNHhDRmZQNXJPNmdRbm5Wdk1tYVpxSkM4NGhBa1FKQXNSZmpLNXN2V01ERnBxMm1iei9SNmcKL3hLUmI0b1FxdFczSCtaYjNjYVgvdUd3Qnh1OGxLV2JVbGREWll0Rm5ZVS8rdThpNnFUem4vUnc3TWtrRFo4cgorSlU0NU5zQ0F3RUFBVEFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBWktsUUNaVEtkMjBuQWxLayt6NGFxY1V4CngyVlA0bW0xR0lNT0NOUStwWUo0dWU2RXRvZlpyZWdwYkRRd0NmQ2NwSVUvdmQvY0trN3JXdnArUExHcDBsdVYKS281a2hjWmp0YklTM2FuQXZmRzNtdm03OU1Wd2tJRVZ4QVJHQ216UGxqR1c5eHRqQitMaFhDRGFSamdFblJRaApzV3FpTEdmd0w4L3g1eHpqUmRMNU93bjBTOTNlTzRKYmkxR3RibnJhTVVkWmFJamloRnhWZGdVamx0aGJHUjJjCmtOZ0VybGFMcFg5cnVFWTd4L1JWWWdpcFdVTDBSUEtvN3dlQ3hZUmJtSHJra2hZOGFwRUFib2VjMENBeGZJeDcKbDIwNitnY3ZjRTQzQnVFZHgrQkV3V3dianpvUjFHZ2dOb2R2WEVJTHlkcjlPOFlFcWNmbGNJbE1VSVJsbWc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
    eks_node_group                    = {}
    karpenter_interruption_queue_name = "saas-eks-mock-karpenter"
  }
}

dependency "data" {
  config_path                             = "../20-data"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
  mock_outputs = {
    keycloak_db_endpoint = "mock.rds.amazonaws.com:5432"
  }
}

dependency "observability" {
  config_path                             = "../40-observability"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "show"]
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
