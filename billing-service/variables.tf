variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "dev | test | prod. Namespaces the Secrets Manager lookups (saas/<env>/*)."
}

# ── Inputs from the platform layers via Terragrunt dependency ────────────────
variable "billing_db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the billing database credentials. From 20-data."
}
variable "redis_endpoint" {
  type        = string
  description = "ElastiCache primary endpoint. From 20-data."
}
variable "kafka_bootstrap_brokers" {
  type        = string
  description = "MSK bootstrap brokers. From 20-data."
}
variable "schema_registry_url" {
  type        = string
  description = <<-EOT
    Confluent-compatible schema registry URL. The Avro clients (Confluent
    KafkaAvroSerializer / Deserializer) speak the Confluent REST protocol, which
    AWS Glue cannot serve — this points at the in-cluster Apicurio ccompat
    endpoint (gitops/infra/schema-registry).
  EOT
  default     = "http://schema-registry.schema-registry.svc.cluster.local:8080/apis/ccompat/v7"
}
