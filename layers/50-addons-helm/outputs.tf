output "cluster_name" {
  description = "Cluster these addons were installed into."
  value       = var.cluster_name
}

output "observability_stack" {
  description = "Which observability stack the OTel collector was pointed at."
  value       = var.observability
}
