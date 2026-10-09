variable "description" {
  description = "Human-readable purpose of the key."
  type        = string
}

variable "alias" {
  description = "Alias for the key, including the 'alias/' prefix."
  type        = string

  validation {
    condition     = startswith(var.alias, "alias/")
    error_message = "alias must start with 'alias/'."
  }
}

variable "deletion_window_in_days" {
  description = "Waiting period before a scheduled key deletion completes (7-30)."
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Enable automatic annual rotation of the key material."
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs_access" {
  description = "Grant the regional CloudWatch Logs service principal use of the key (only for keys that encrypt a log group)."
  type        = bool
  default     = false
}

variable "region" {
  description = "Region of the CloudWatch Logs service principal. Required when enable_cloudwatch_logs_access is true."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
