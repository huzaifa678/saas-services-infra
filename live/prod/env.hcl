# prod: multi-AZ, private-only EKS endpoint fronted by Verified Access.
locals {
  project     = "saas"
  environment = "prod"
  region      = "us-east-1"

  auth_provider = "keycloak"
  observability = "elk"

  sizing = {
    eks_node_desired_size = 6
  }
}
