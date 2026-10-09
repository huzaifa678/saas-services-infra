output "ecr_repository_urls" {
  description = "Map of repository name (service or Crossplane function) => ECR repository URL. Consumed by the service deploy pipelines."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of repository name (service or Crossplane function) => repository ARN, for scoping pull/push IAM policies."
  value       = module.ecr.repository_arns
}

output "registry_url" {
  description = "ECR registry host for this account/region. Service images are <registry_url>/<service>."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "helm_oci_url" {
  description = "OCI base the microservices ApplicationSet pulls charts from (charts land at helm/<chart>)."
  value       = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/helm"
}
