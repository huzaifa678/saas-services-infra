region       = "us-east-1"
cluster_name = "saas-eks-dev"

vpc_cidr        = "10.0.0.0/16"
public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

node_instance_type = "t3.small"
desired_size       = 2
min_size           = 1
max_size           = 3

# Dev uses custom auth-service (lighter, no Keycloak overhead)
auth_provider = "auth-service"

# ─── Sensitive — set via TF_VAR_* env vars or CI/CD secrets ──────────────────
# auth_db_password           = ""  # TF_VAR_auth_db_password
# subscription_db_password   = ""  # TF_VAR_subscription_db_password
# billing_db_password        = ""  # TF_VAR_billing_db_password
# usage_db_password          = ""  # TF_VAR_usage_db_password
# opensearch_master_password = ""  # TF_VAR_opensearch_master_password
# openai_api_key             = ""  # TF_VAR_openai_api_key
