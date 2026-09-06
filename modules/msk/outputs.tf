output "bootstrap_brokers" {
  description = "Plaintext (port 9092) bootstrap brokers. Empty under the enforced TLS-only posture — kept for backwards compatibility only. Clients should use bootstrap_brokers_sasl_iam."
  value       = aws_msk_cluster.this.bootstrap_brokers
}

output "bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM bootstrap brokers (port 9098). What in-mesh workloads using EKS Pod Identity connect to."
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "bootstrap_brokers_tls" {
  description = "TLS bootstrap brokers (port 9094), used for mutual-TLS client-certificate auth when tls_client_authority_arns is set."
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "cluster_arn" {
  value = aws_msk_cluster.this.arn
}
