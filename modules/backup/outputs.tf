output "vault_arn" {
  description = "ARN of the backup vault holding this layer's recovery points."
  value       = aws_backup_vault.this.arn
}

output "vault_name" {
  value = aws_backup_vault.this.name
}

output "plan_id" {
  value = aws_backup_plan.this.id
}

output "role_arn" {
  description = "IAM role AWS Backup assumes to snapshot and copy the selected resources."
  value       = aws_iam_role.backup.arn
}
