variable "repositories" {
  description = "Repository names to create — one per microservice image."
  type        = list(string)

  validation {
    condition     = length(var.repositories) == length(toset(var.repositories))
    error_message = "repositories must not contain duplicate names."
  }
}

variable "kms_encryption" {
  description = "Encrypt repositories with a CMK (KMS). False uses ECR-managed AES256."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "CMK ARN used when kms_encryption is true. May be known-after-apply; empty uses the AWS-managed aws/ecr key."
  type        = string
  default     = ""
}

variable "immutable_tags" {
  description = "Enforce IMMUTABLE image tags so a tag can never be silently repointed."
  type        = bool
  default     = true
}

variable "scan_on_push" {
  description = "Run the native image scan on every push."
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Tagged images to retain per repo before the lifecycle policy expires the oldest."
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

variable "force_delete" {
  description = "Allow terraform destroy to delete a repository that still holds images. Keep false in prod."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
