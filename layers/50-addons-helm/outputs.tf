output "cluster_name" {
  description = "Cluster these addons were installed into."
  value       = var.cluster_name
}

output "observability_stack" {
  description = "Observability stack(s) selected for this cluster."
  value       = var.observability
}
