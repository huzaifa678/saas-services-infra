terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

# AWS Backup gives the data tier retention BEYOND the RDS automated-backup ceiling
# (35 days) and, optionally, a cross-region copy for DR — neither of which the RDS
# instance itself can do. It complements (does not replace) the instance's own
# automated backups / PITR configured in modules/rds.

resource "aws_backup_vault" "this" {
  name        = "${var.name}-vault"
  kms_key_arn = var.kms_key_arn
  tags        = var.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${var.name}-backup"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# AWS-managed policy scoped to exactly what the Backup service needs to snapshot
# and copy the selected resources (includes the cross-region copy permissions).
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-plan"

  rule {
    rule_name         = "${var.name}-daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.schedule
    start_window      = var.start_window_minutes
    completion_window = var.completion_window_minutes

    lifecycle {
      # null skips the cold-storage transition entirely.
      cold_storage_after = var.cold_storage_after_days > 0 ? var.cold_storage_after_days : null
      delete_after       = var.delete_after_days
    }

    # Cross-region DR copy, only when a destination vault ARN is supplied.
    dynamic "copy_action" {
      for_each = var.cross_region_vault_arn != "" ? [1] : []
      content {
        destination_vault_arn = var.cross_region_vault_arn
        lifecycle {
          cold_storage_after = var.cold_storage_after_days > 0 ? var.cold_storage_after_days : null
          delete_after       = var.delete_after_days
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "this" {
  name         = "${var.name}-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.this.id
  resources    = var.resource_arns
}

# Cross-variable invariants the per-variable validation cannot express.
resource "terraform_data" "backup_invariants" {
  input = var.name

  lifecycle {
    precondition {
      condition     = var.cold_storage_after_days <= 0 || var.delete_after_days >= var.cold_storage_after_days + 90
      error_message = "AWS Backup requires delete_after to be at least cold_storage_after + 90 days."
    }

    precondition {
      condition     = var.completion_window_minutes > var.start_window_minutes
      error_message = "completion_window_minutes must exceed start_window_minutes."
    }

    precondition {
      condition     = length(var.resource_arns) > 0
      error_message = "resource_arns must be non-empty; a backup plan with no selection protects nothing."
    }
  }
}
