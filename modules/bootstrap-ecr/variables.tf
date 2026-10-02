variable "repository_name" {
  description = "ECR repository name for the CI toolchain image (per env)."
  type        = string
}

variable "kms_key_arn" {
  description = "CMK for at-rest encryption. Empty falls back to ECR-managed AES256."
  type        = string
  default     = ""
}

variable "immutable_tags" {
  description = "Enforce IMMUTABLE image tags so an env tag can never be silently repointed."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Tagged images to retain before the lifecycle policy expires the oldest."
  type        = number
  default     = 10
}

variable "untagged_expire_days" {
  description = "Days after which untagged (superseded) layers are expired."
  type        = number
  default     = 3
}

variable "tag_prefixes" {
  description = "Tag prefixes the retention rule applies to (env tags + content digests)."
  type        = list(string)
  default     = ["dev", "test", "prod", "sha-", "v"]
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
