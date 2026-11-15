variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "dev | test | prod. Namespaces nothing here (saas/e2e is per-cluster), kept for parity."
}

# ── Inputs from the platform layers via Terragrunt dependency ────────────────
variable "kafka_bootstrap_brokers" {
  type        = string
  description = "MSK bootstrap brokers (SASL/IAM endpoint). From 20-data."
}

# NOTE: the Keycloak client secret is NOT a Terraform input. The `saas-e2e`
# client is declared in the CD repo's realm import with no pinned secret;
# Keycloak generates it per env and scripts/sync-keycloak-secret.sh writes it
# into the saas/e2e secret. So there is nothing to add to the SOPS env for this.
