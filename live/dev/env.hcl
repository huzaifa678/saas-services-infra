# dev: single-AZ, public EKS endpoint (CIDR-allow-listed), no Verified Access.
locals {
  project     = "saas"
  environment = "dev"
  region      = "us-east-1"

  auth_provider = "keycloak"
  observability = "elk"

  # dev has a public endpoint, so this allow-list may not be empty. Guardrails
  # rejects 0.0.0.0/0 outright.
  allowed_public_access_cidrs = ["203.0.113.0/24"]

  sizing = {
    eks_node_desired_size = 3
    eks_node_min_size     = 1
    eks_node_max_size     = 5
  }
}
