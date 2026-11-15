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
variable "schema_registry_url" {
  type        = string
  description = <<-EOT
    Confluent-compatible schema registry URL. kafkajs's
    @kafkajs/confluent-schema-registry speaks the Confluent REST protocol, which
    AWS Glue cannot serve — this points at the in-cluster Apicurio ccompat
    endpoint (gitops/infra/schema-registry).
  EOT
  default     = "http://schema-registry.schema-registry.svc.cluster.local:8080/apis/ccompat/v7"
}
