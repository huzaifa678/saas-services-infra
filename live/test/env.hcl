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

  # test additionally runs the standalone auth-service.
  extra_databases = {
    auth = { name = "saas-auth-db", db_name = "auth_db", db_username = "auth_user", password = null }
  }

  # Cost-optimised launch footprint for test.
  # Grow to `growth` capacity tier as scale increases.
  capacity_tier = "launch_lite"

  sizing = {
    rds_instance_class = "db.t4g.micro"
  }

  ava = {
    # Must match the token's `iss` claim EXACTLY, including Auth0's trailing slash.
    oidc_issuer = "https://dev-oqegk1bhhostcaj0.us.auth0.com/"

    custom_subdomain = "ava-test.freeeasycrypto.com"
  }
}
