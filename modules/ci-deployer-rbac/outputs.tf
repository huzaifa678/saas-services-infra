output "deployer_group" {
  description = "The Kubernetes group the ci-deployer RBAC authorizes."
  value       = var.deployer_group
}

output "applied_manifests" {
  description = "Manifest keys applied, for downstream depends_on ordering."
  value       = keys(data.kubectl_file_documents.ci_deployer.manifests)
}
