variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "dev | test | prod. Namespaces the Secrets Manager lookups (saas/<env>/*)."
}

# ── Inputs from the platform layers via Terragrunt dependency ────────────────
variable "agent_db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the agent database credentials. From 20-data."
}
variable "kafka_bootstrap_brokers" {
  type        = string
  description = "MSK bootstrap brokers (SASL/IAM endpoint). From 20-data."
}
