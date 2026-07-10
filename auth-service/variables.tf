variable "region" {
  type    = string
  default = "us-east-1"
}


variable "auth_jwt_secret" {
  type      = string
  sensitive = true
}

variable "auth_jwt_refresh_secret" {
  type      = string
  sensitive = true
}

# ── Input from the platform data layer (20-data) via Terragrunt dependency ────
variable "auth_db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the auth database credentials. From 20-data."
}
