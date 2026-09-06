# prod: multi-AZ, private-only EKS endpoint fronted by Verified Access.
locals {
  project     = "saas"
  environment = "prod"
  region      = "us-east-1"

  auth_provider = "keycloak"
  # prod runs both self-hosted stacks. Primary (first) = elk drives the
  # AWS-managed backend (OpenSearch); grafana adds the self-hosted Loki/Grafana.
  observability = ["elk", "grafana"]

  # Cost-optimised launch footprint for prod.
  # Grow to `launch_lite` or `growth` capacity tier as the scale increases.
  capacity_tier = "launch"

  sizing = {}
}
