variable "name" {
  type        = string
  description = "Replication group identifier."
  default     = "saas-redis"
}

variable "node_type" {
  type        = string
  description = "Cache node type. Supplied by guardrails sizing."
  default     = "cache.t4g.micro"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the cache subnet group."
}

variable "redis_sg_id" {
  type        = string
  description = "Security group ID for ElastiCache."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for at-rest and auth-token secret encryption."
}

variable "engine_version" {
  type    = string
  default = "7.0"
}

variable "parameter_group_name" {
  type    = string
  default = "default.redis7"
}

variable "apply_immediately" {
  type    = bool
  default = true
}

# --- Posture, supplied by the guardrails module -----------------------------

variable "at_rest_encryption_enabled" {
  type    = bool
  default = true
}

variable "transit_encryption_enabled" {
  type    = bool
  default = true
}

variable "auth_token_enabled" {
  type        = bool
  description = "Generate an AUTH token, store it in Secrets Manager, and require it."
  default     = true
}

variable "num_replicas" {
  type        = number
  description = "Read replicas per node group. Must be >= 1 for automatic failover."
  default     = 0
}

variable "automatic_failover_enabled" {
  type    = bool
  default = false
}

variable "multi_az_enabled" {
  type    = bool
  default = false
}

variable "snapshot_retention_days" {
  type    = number
  default = 0
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
