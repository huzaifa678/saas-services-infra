variable "region" {
  type    = string
  default = "us-east-1"
}


# ── Inputs from the platform layers via Terragrunt dependency ────────────────
variable "subscription_db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the subscription database credentials. From 20-data."
}
variable "kafka_bootstrap_brokers" {
  type        = string
  description = "MSK bootstrap brokers. From 20-data."
}
variable "schema_registry_arn" {
  type        = string
  description = "Glue schema registry ARN. From 00-network."
}
