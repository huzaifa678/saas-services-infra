data "aws_availability_zones" "available" {}

locals {
  ordered_public_subnets  = sort(var.public_subnets)
  ordered_private_subnets = sort(var.private_subnets)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name                 = "${var.cluster_name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = local.ordered_public_subnets
  private_subnets      = local.ordered_private_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = { Name = "${var.cluster_name}-vpc" }
}

module "eks" {
  source = "./modules/eks"

  cluster_name                         = var.cluster_name
  kubernetes_version                   = var.kubernetes_version
  private_subnets                      = module.vpc.private_subnets
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  vpc_id                               = module.vpc.vpc_id
  node_instance_type                   = var.node_instance_type
  desired_size                         = var.desired_size
  min_size                             = var.min_size
  max_size                             = var.max_size
  region                               = var.region
}

module "k8s" {
  source = "./modules/k8s-and-helm"

  cluster_name                    = module.eks.eks_cluster_name
  cluster_endpoint                = module.eks.eks_cluster_endpoint
  cluster_ca                      = module.eks.eks_cluster_ca
  eks_node_group                  = module.eks.eks_node_group
  vpc                             = module.vpc
  vpc_id                          = module.vpc.vpc_id
  region                          = var.region
  cert_manager_irsa_role_arn      = module.eks.cert_manager_irsa_role_arn
  external_dns_irsa_role_arn      = module.eks.external_dns_irsa_role_arn
  aws_lb_controller_irsa_role_arn = module.eks.aws_lb_controller_irsa_role_arn
}

module "rds_auth" {
  source      = "./modules/rds"
  name        = "saas-auth-db"
  db_name     = "auth_db"
  db_username = "auth_user"
  db_password = var.auth_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.eks.rds_sg_id
  port        = "5432"
}

module "rds_subscription" {
  source      = "./modules/rds"
  name        = "saas-subscription-db"
  db_name     = "subscription_db"
  db_username = "subscription_user"
  db_password = var.subscription_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.eks.rds_sg_id
  port        = "5433"
}

module "rds_billing" {
  source      = "./modules/rds"
  name        = "saas-billing-db"
  db_name     = "billing_db"
  db_username = "billing_user"
  db_password = var.billing_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.eks.rds_sg_id
  port        = "5434"
}


module "rds_usage" {
  source      = "./modules/rds"
  name        = "saas-usage-db"
  db_name     = "usage_db"
  db_username = "usage_user"
  db_password = var.usage_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.eks.rds_sg_id
  port        = "5435"
}

module "rds_keycloak" {
  source      = "./modules/rds"
  name        = "keycloak-db"
  db_name     = "keycloak_db"
  db_username = "keycloak_user"
  db_password = var.keycloak_db_password
  subnet_ids  = module.vpc.private_subnets
  rds_sg_id   = module.eks.rds_sg_id
  port        = "5436"
}


module "elasticache" {
  source      = "./modules/elasticache"
  name        = "saas-redis"
  subnet_ids  = module.vpc.private_subnets
  redis_sg_id = module.eks.redis_sg_id
}

module "kafka" {
  source                 = "./modules/kafka"
  cluster_name           = "saas-msk"
  subnet_ids             = slice(module.vpc.private_subnets, 0, 2)
  msk_sg_id              = module.eks.msk_sg_id
  number_of_broker_nodes = 2
}

module "grafana" {
  source            = "./modules/grafana"
  workspace_name    = "saas-grafana"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
}

module "elk" {
  source               = "./modules/elk"
  domain_name          = "saas-opensearch"
  subnet_ids           = module.vpc.private_subnets
  opensearch_sg_id     = module.eks.opensearch_sg_id
  master_user_password = var.opensearch_master_password
}


resource "aws_glue_registry" "schema_registry" {
  registry_name = "saas-schema-registry"
}

locals {
  services = ["api-gateway", "auth-service", "subscription-service", "billing-service", "usage-service"]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = each.key }
}
