region       = "us-east-1"
cluster_name = "saas-eks-prod"

vpc_cidr        = "10.1.0.0/16"
public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnets = ["10.1.3.0/24", "10.1.4.0/24"]

kubernetes_version = "1.32"

enable_public_access = false
enable_ssm_access    = true   # Zero-VPN: private kubectl via SSM port-forward (prod only)

node_instance_type = "t3.large"
desired_size       = 3
min_size           = 2
max_size           = 10

# Prod uses Keycloak for enterprise SSO
auth_provider = "keycloak"

observability = "elk"

# ─── Sensitive — set via TF_VAR_* env vars or CI/CD secrets ──────────────────
# keycloak_db_password       = ""  # TF_VAR_keycloak_db_password
# subscription_db_password   = ""  # TF_VAR_subscription_db_password
# billing_db_password        = ""  # TF_VAR_billing_db_password
# usage_db_password          = ""  # TF_VAR_usage_db_password
# opensearch_master_password = ""  # TF_VAR_opensearch_master_password
# openai_api_key             = ""  # TF_VAR_openai_api_key
