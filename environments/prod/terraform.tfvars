region       = "us-east-1"
cluster_name = "saas-eks-prod"

vpc_cidr        = "10.1.0.0/16"
public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnets = ["10.1.3.0/24", "10.1.4.0/24"]

kubernetes_version = "1.32"

enable_public_access   = false
enable_verified_access = true

ava_subnet_ids    = ["10.1.3.0/24", "10.1.4.0/24"]
keycloak_hostname = ""
ava_oidc_issuer   = "https://DOMAIN.auth0.com" // example domain for now, TODO: adjust based on actual OIDC provider
# ava_oidc_client_id     = ""  # TF_VAR_ava_oidc_client_id
# ava_oidc_client_secret = ""  # TF_VAR_ava_oidc_client_secret

node_instance_type = "t3.large"
desired_size       = 3
min_size           = 2
max_size           = 10

auth_provider = "keycloak"
observability = "elk"

# ─── Sensitive — can beset via TF_VAR_* env vars or CI/CD secrets ──────────────────
# keycloak_db_password       = ""  # TF_VAR_keycloak_db_password
# subscription_db_password   = ""  # TF_VAR_subscription_db_password
# billing_db_password        = ""  # TF_VAR_billing_db_password
# usage_db_password          = ""  # TF_VAR_usage_db_password
# opensearch_master_password = ""  # TF_VAR_opensearch_master_password
# openai_api_key             = ""  # TF_VAR_openai_api_key
# ava_oidc_client_id         = ""  # TF_VAR_ava_oidc_client_id
# ava_oidc_client_secret     = ""  # TF_VAR_ava_oidc_client_secret
