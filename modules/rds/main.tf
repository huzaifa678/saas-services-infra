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
}

locals {
  password = coalesce(var.db_password, random_password.db_password.result)

  engine_major = split(".", var.engine_version)[0]
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$&*"
  upper            = true
  lower            = true
  numeric          = true
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = var.name

  engine               = "postgres"
  engine_version       = var.engine_version
  family               = "postgres${local.engine_major}"
  major_engine_version = local.engine_major
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  port     = tonumber(var.port)

  # The credentials are surfaced through the custom secret below (which also
  # carries endpoint/db_name for the service consumers), so the module's own
  # managed-master-password feature is disabled and the password passed in.
  manage_master_user_password = false
  password                    = local.password

  multi_az               = var.multi_az
  publicly_accessible    = var.publicly_accessible
  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids
  vpc_security_group_ids = [var.rds_sg_id]

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_arn

  backup_retention_period             = var.backup_retention_days
  deletion_protection                 = var.deletion_protection
  iam_database_authentication_enabled = var.iam_database_authentication
  copy_tags_to_snapshot               = var.copy_tags_to_snapshot

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_days : null

  skip_final_snapshot = var.skip_final_snapshot

  tags = merge(var.tags, { Name = var.name })
}

# Custom secret preserved from the previous implementation: service roots parse
# {username,password,endpoint,db_name} out of it, so its shape must not change.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}-secret"
  recovery_window_in_days = 7
  kms_key_id              = var.kms_key_arn
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = local.password
    endpoint = module.db.db_instance_endpoint
    db_name  = var.db_name
  })
}

# Cross-variable invariants that neither the module nor per-variable validation
# can express on their own.
resource "terraform_data" "rds_invariants" {
  input = var.name

  lifecycle {
    precondition {
      condition     = !(var.deletion_protection && var.skip_final_snapshot)
      error_message = "deletion_protection and skip_final_snapshot cannot both be true: lifting the former would silently discard the data."
    }

    precondition {
      condition     = var.publicly_accessible == false
      error_message = "INVARIANT: RDS must never be publicly accessible."
    }

    precondition {
      condition     = var.storage_encrypted
      error_message = "INVARIANT: RDS storage encryption cannot be disabled."
    }
  }
}
