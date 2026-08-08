variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "dev | test | prod. Namespaces the Secrets Manager lookups (saas/<env>/*)."
}

# ── Input from the platform data layer (20-data) via Terragrunt dependency ────
variable "auth_db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the auth database credentials. From 20-data."
}
