# test: multi-AZ, private-only EKS endpoint fronted by Verified Access.
locals {
  project     = "saas"
  environment = "test"
  region      = "us-east-1"

  auth_provider = "auth-service"
  observability = "elk"

  sizing = {
    eks_node_desired_size = 3
  }
}
