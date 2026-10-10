# test: multi-AZ, private-only EKS endpoint fronted by Verified Access.
locals {
  project     = "saas"
  environment = "test"
  region      = "us-east-1"

  # Staging mirrors prod's identity provider (Keycloak). This provisions the
  # keycloak RDS in 20-data and makes the platform consistent with the CD repo,
  # which deploys Keycloak + points Backstage at Keycloak OIDC in staging.
  auth_provider = "keycloak"
  observability = ["elk"]

  # Cost-optimised launch footprint for test.
  # Grow to `growth` capacity tier as scale increases.
  capacity_tier = "launch_lite"

  sizing = {
    rds_instance_class = "db.t4g.micro"
  }

  ava = {
    oidc_issuer = "dev-oqegk1bhhostcaj0.us.auth0.com" # TODO: replacement to be done

    custom_subdomain = "ava.freeeasycrypto.com"
  }
}
