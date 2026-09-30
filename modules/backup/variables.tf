variable "name" {
  type        = string
  description = "Name prefix for the vault, plan, selection, and IAM role."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN encrypting the backup vault (recovery points)."
}

variable "resource_arns" {
  type        = list(string)
  description = "ARNs of the resources to back up (the RDS instances in this layer)."
}

variable "schedule" {
  type        = string
  description = "Cron expression (UTC) for the daily backup rule."
  default     = "cron(0 5 * * ? *)"
}

variable "start_window_minutes" {
  type        = number
  description = "Minutes AWS Backup waits for a job to start before treating it as missed."
  default     = 60
}

variable "completion_window_minutes" {
  type        = number
  description = "Minutes a backup job may run before AWS Backup cancels it. Must exceed start_window_minutes."
  default     = 480
}

variable "cold_storage_after_days" {
  type        = number
  description = "Transition recovery points to cold storage after N days (0 disables cold storage). When >0, delete_after_days must be >= this + 90 (an AWS rule)."
  default     = 0
}

variable "delete_after_days" {
  type        = number
  description = "Retain recovery points for N days before expiry. This is the long-term retention beyond RDS automated backups (which cap at 35 days)."
}

variable "cross_region_vault_arn" {
  type        = string
  description = "Destination backup-vault ARN in a DR region. When set, each recovery point is copied there for cross-region durability. Empty disables the copy (the vault must already exist in the DR region)."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
