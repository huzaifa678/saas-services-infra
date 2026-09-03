# prod: multi-AZ, private-only EKS endpoint fronted by Verified Access.
locals {
  project     = "saas"
  environment = "prod"
  region      = "us-east-1"

  auth_provider = "keycloak"
  observability = "elk"

  # Cost-optimised launch footprint for prod.
  # Grow to `launch_lite` or `growth` capacity tier as the scale increases.
  capacity_tier = "launch"

  sizing = {}
}
