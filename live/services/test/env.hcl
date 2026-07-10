# Service-tier environment. Separate from the platform envs under live/<env>/;
# services depend on the matching platform env's 00-network and 20-data outputs.
locals {
  project     = "saas"
  environment = "test"
  region      = "us-east-1"
}
