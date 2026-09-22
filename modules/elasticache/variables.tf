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
  type        = string
  description = "Override the parameter group. When null, the module picks default.redis7 for a single shard and default.redis7.cluster.on for cluster mode."
  default     = null
}

variable "apply_immediately" {
  type    = bool
  default = true
}

# --- Capacity, supplied by the guardrails sizing tier -----------------------

variable "num_shards" {
  type        = number
  description = "Number of node groups (shards). 1 = cluster-mode-disabled (historical behaviour); >1 enables Redis Cluster mode with hash-slot sharding."
  default     = 1

  validation {
    condition     = var.num_shards >= 1
    error_message = "num_shards must be >= 1."
  }
}

variable "num_replicas" {
  type        = number
  description = "Read replicas per node group. Must be >= 1 for automatic failover."
  default     = 0
}

# --- Application Auto Scaling (opt-in) --------------------------------------

variable "autoscaling_enabled" {
  type        = bool
  description = "Enable shard (node group) auto scaling. Requires cluster mode (num_shards > 1)."
  default     = false
}

variable "autoscaling_min_shards" {
  type    = number
  default = 1
}

variable "autoscaling_max_shards" {
  type    = number
  default = 1
}

variable "autoscaling_replicas_enabled" {
  type        = bool
  description = "Enable replica auto scaling. Requires cluster mode (num_shards > 1)."
  default     = false
}

variable "autoscaling_min_replicas" {
  type    = number
  default = 1
}

variable "autoscaling_max_replicas" {
  type    = number
  default = 3
}

variable "autoscaling_target_memory_percent" {
  type        = number
  description = "Target database memory usage (%, counted for eviction) that shard auto scaling holds by adding/removing shards."
  default     = 65
}

variable "autoscaling_target_cpu_percent" {
  type        = number
  description = "Target engine CPU utilisation (%) that replica auto scaling holds by adding/removing read replicas."
  default     = 70
}

variable "autoscaling_scale_in_cooldown" {
  type    = number
  default = 300
}

variable "autoscaling_scale_out_cooldown" {
  type    = number
  default = 120
}

# --- RBAC (opt-in) ----------------------------------------------------------

variable "rbac_enabled" {
  type        = bool
  description = "Attach a Redis ACL user group to the cluster instead of a shared AUTH token. Enables per-service self-service cache tenants (Crossplane-managed users). Mutually exclusive with auth_token_enabled."
  default     = false
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
  description = "Generate an AUTH token, store it in Secrets Manager, and require it. Ignored when rbac_enabled is true."
  default     = true
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
