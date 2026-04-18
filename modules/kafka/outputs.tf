output "bootstrap_brokers" {
  value = aws_msk_cluster.this.bootstrap_brokers
}

output "cluster_arn" {
  value = aws_msk_cluster.this.arn
}
