terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
  }

  # Partial backend —> supplying the rest via:
  # terraform init -backend-config=environments/<env>/backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.region
}
