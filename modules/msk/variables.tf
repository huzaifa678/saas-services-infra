variable "cluster_name" {
  type    = string
  default = "saas-msk"
}

variable "kafka_version" {
  type    = string
  default = "3.7.x.kraft"
}

variable "number_of_broker_nodes" {
  type        = number
  description = "Broker count. Must be a multiple of the client subnet count."
  default     = 2
}

variable "broker_instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "broker_volume_size" {
  type    = number
  default = 20
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs (number_of_broker_nodes must be a multiple of this count)"
}

variable "msk_sg_id" {
  type = string
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for MSK at-rest and log encryption"
}

# --- Posture, supplied by the guardrails module -----------------------------

variable "unauthenticated_access" {
  type        = bool
  description = "Must remain false. Present only so the invariant is explicit and testable."
  default     = false
}

variable "sasl_iam_enabled" {
  type        = bool
  description = "Enable SASL/IAM client authentication (broker port 9098)."
  default     = true
}

variable "sasl_scram_enabled" {
  type        = bool
  description = "Enable SASL/SCRAM client authentication (broker port 9096)."
  default     = false
}

variable "client_broker_encryption" {
  type        = string
  description = "Client-broker encryption. TLS only."
  default     = "TLS"

  validation {
    condition     = var.client_broker_encryption == "TLS"
    error_message = "client_broker_encryption must be TLS."
  }
}

variable "in_cluster_encryption" {
  type        = bool
  description = "Encrypt broker-to-broker traffic."
  default     = true
}

variable "enhanced_monitoring" {
  type        = string
  description = "DEFAULT | PER_BROKER | PER_TOPIC_PER_BROKER | PER_TOPIC_PER_PARTITION"
  default     = "DEFAULT"
}

# --- Cluster configuration --------------------------------------------------

variable "auto_create_topics" {
  type        = bool
  description = "Allow producers to implicitly create topics."
  default     = true
}

variable "num_partitions" {
  type    = number
  default = 3
}

variable "log_retention_hours" {
  type    = number
  default = 168
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch retention for broker logs."
  default     = 7
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
