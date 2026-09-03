# test: multi-AZ, private-only EKS endpoint fronted by Verified Access.
locals {
  project     = "saas"
  environment = "test"
  region      = "us-east-1"

  auth_provider = "auth-service"
  observability = "elk"

  # Cost-optimised launch footprint for test.
  # Grow to `growth` capacity tier as scale increases.
  capacity_tier = "launch_lite"

  sizing = {}
}
