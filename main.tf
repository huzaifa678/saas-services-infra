data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name                 = "${var.cluster_name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = local.ordered_public_subnets
  private_subnets      = local.ordered_private_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                  = true
  flow_log_destination_type        = "cloud-watch-logs"
  flow_log_destination_arn         = aws_cloudwatch_log_group.vpc_flow_logs.arn
  flow_log_cloudwatch_iam_role_arn = aws_iam_role.vpc_flow_log.arn
  flow_log_traffic_type            = "ALL"

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"                    = var.cluster_name
  }

  tags = { Name = "${var.cluster_name}-vpc" }
}

module "security_group" {
  source = "./modules/security-group"

  cluster_name           = var.cluster_name
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  enable_verified_access = var.enable_verified_access
  ava_subnet_ids         = var.ava_subnet_ids
}

module "eks" {
  source = "./modules/eks"

  cluster_name           = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  private_subnets        = module.vpc.private_subnets
  vpc_id                 = module.vpc.vpc_id
  enable_public_access   = var.enable_public_access
  enable_verified_access = var.enable_verified_access
  ava_oidc_issuer        = var.ava_oidc_issuer
  ava_oidc_client_id     = var.ava_oidc_client_id
  ava_oidc_client_secret = var.ava_oidc_client_secret
  ava_subnet_ids         = var.ava_subnet_ids
  vpc_cidr               = var.vpc_cidr
  node_instance_type     = var.node_instance_type
  desired_size           = var.desired_size
  min_size               = var.min_size
  max_size               = var.max_size
  region                 = var.region
  kms_key_arn            = aws_kms_key.main.arn
  eks_nodes_sg_id        = module.security_group.eks_nodes_security_group_id
  ebs_csi_role_arn       = module.iam.ebs_csi_role_arn
}

module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
}

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = module.eks.eks_cluster_name
  principal_arn = module.iam.karpenter_node_role_arn
  type          = "EC2_LINUX"
}

module "k8s" {
  source = "./modules/k8s-and-helm"

  cluster_name                      = module.eks.eks_cluster_name
  cluster_endpoint                  = module.eks.eks_cluster_endpoint
  cluster_ca                        = module.eks.eks_cluster_ca
  eks_node_group                    = module.eks.eks_node_group
  vpc                               = module.vpc
  vpc_id                            = module.vpc.vpc_id
  region                            = var.region
  karpenter_interruption_queue_name = module.iam.karpenter_interruption_queue_name
  auth_provider                     = var.auth_provider
  keycloak_db_endpoint              = var.auth_provider == "keycloak" ? module.rds_keycloak[0].endpoint : ""
  keycloak_hostname                 = var.keycloak_hostname
  auth0_issuer                      = var.auth0_issuer
  auth0_client_id                   = var.auth0_client_id
  auth0_client_secret               = var.auth0_client_secret
  observability                     = var.observability
}

module "rds_auth" {
  count       = var.auth_provider == "auth-service" ? 1 : 0
  source      = "./modules/rds"
  name        = "saas-auth-db"
  db_name     = "auth_db"
  db_username = "auth_user"
  db_password = var.auth_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.security_group.rds_sg_id
  port        = "5432"
  kms_key_arn = aws_kms_key.main.arn
}

module "rds_subscription" {
  source      = "./modules/rds"
  name        = "saas-subscription-db"
  db_name     = "subscription_db"
  db_username = "subscription_user"
  db_password = var.subscription_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.security_group.rds_sg_id
  port        = "5432"
  kms_key_arn = aws_kms_key.main.arn
}

module "rds_billing" {
  source      = "./modules/rds"
  name        = "saas-billing-db"
  db_name     = "billing_db"
  db_username = "billing_user"
  db_password = var.billing_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.security_group.rds_sg_id
  port        = "5432"
  kms_key_arn = aws_kms_key.main.arn
}

module "rds_usage" {
  source      = "./modules/rds"
  name        = "saas-usage-db"
  db_name     = "usage_db"
  db_username = "usage_user"
  db_password = var.usage_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.security_group.rds_sg_id
  port        = "5432"
  kms_key_arn = aws_kms_key.main.arn
}

module "rds_keycloak" {
  count       = var.auth_provider == "keycloak" ? 1 : 0
  source      = "./modules/rds"
  name        = "keycloak-db"
  db_name     = "keycloak_db"
  db_username = "keycloak_user"
  db_password = var.keycloak_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.security_group.rds_sg_id
  port        = "5432"
  kms_key_arn = aws_kms_key.main.arn
}

module "elasticache" {
  source      = "./modules/elasticache"
  name        = "saas-redis"
  subnet_ids  = module.vpc.private_subnets
  redis_sg_id = module.security_group.redis_sg_id
  kms_key_arn = aws_kms_key.main.arn
}

module "msk" {
  source                 = "./modules/msk"
  cluster_name           = "saas-msk"
  subnet_ids             = slice(module.vpc.private_subnets, 0, 2)
  msk_sg_id              = module.security_group.msk_sg_id
  number_of_broker_nodes = 2
  kms_key_arn            = aws_kms_key.main.arn
}

module "observability" {
  source = "./modules/observability"

  stack             = var.observability
  cluster_name      = module.eks.eks_cluster_name
  region            = var.region
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer

  # ELK-specific (ignored when stack = "grafana")
  subnet_ids                 = module.vpc.private_subnets
  opensearch_sg_id           = module.security_group.opensearch_sg_id
  opensearch_master_username = var.opensearch_master_username
  opensearch_master_password = var.opensearch_master_password
}
