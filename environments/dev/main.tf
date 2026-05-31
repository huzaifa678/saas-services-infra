terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }

  backend "s3" {
    bucket       = "saas-state-bucket-399849"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
}

module "root" {
  source = ".."

  region                     = var.region
  cluster_name               = var.cluster_name
  kubernetes_version         = var.kubernetes_version
  vpc_cidr                   = var.vpc_cidr
  public_subnets             = var.public_subnets
  private_subnets            = var.private_subnets
  enable_public_access       = var.enable_public_access
  enable_verified_access     = var.enable_verified_access
  node_instance_type         = var.node_instance_type
  desired_size               = var.desired_size
  min_size                   = var.min_size
  max_size                   = var.max_size
  auth_provider              = var.auth_provider
  observability              = var.observability
  auth_db_password           = var.auth_db_password
  subscription_db_password   = var.subscription_db_password
  billing_db_password        = var.billing_db_password
  usage_db_password          = var.usage_db_password
  keycloak_db_password       = var.keycloak_db_password
  opensearch_master_username = var.opensearch_master_username
  opensearch_master_password = var.opensearch_master_password
  openai_api_key             = var.openai_api_key
}
