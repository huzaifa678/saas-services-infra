variable "name" {
  type        = string
  description = "RDS instance identifier"
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Database master username"
}

variable "db_password" {
  type        = string
  description = "Database master password (generated if null)"
  default     = null
  sensitive   = true
}

variable "instance_class" {
  type        = string
  description = "Instance class. Supplied by guardrails sizing."
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GiB. Supplied by guardrails sizing."
  default     = 20
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL engine version."
  default     = "16.6"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group"
}

variable "rds_sg_id" {
  type        = string
  description = "Security group ID for RDS"
}

variable "port" {
  type        = string
  description = "Port number for DB"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for RDS storage, secret, and performance insights encryption"
}

# --- Posture, supplied by the guardrails module -----------------------------

variable "multi_az" {
  type        = bool
  description = "Deploy a standby in a second AZ."
  default     = false
}

variable "publicly_accessible" {
  type        = bool
  description = "Must remain false. Present only so the invariant is explicit and testable."
  default     = false
}

variable "storage_encrypted" {
  type        = bool
  description = "Encrypt storage at rest with kms_key_arn."
  default     = true
}

variable "backup_retention_days" {
  type        = number
  description = "Automated backup retention in days."
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Block `terraform destroy` and console deletion."
  default     = false
}

variable "iam_database_authentication" {
  type        = bool
  description = "Enable IAM database authentication."
  default     = true
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights."
  default     = false
}

variable "performance_insights_retention_days" {
  type        = number
  description = "Performance Insights retention. Must be 7, 731, or a multiple of 31."
  default     = 7
}

variable "copy_tags_to_snapshot" {
  type        = bool
  description = "Propagate instance tags onto snapshots."
  default     = true
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip the final snapshot on destroy. Only ever acceptable in dev."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
