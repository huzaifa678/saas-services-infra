output "verified_access_enabled" {
  description = "Whether this environment fronts the EKS API with Verified Access."
  value       = local.ava_enabled
}

output "verified_access_instance_id" {
  value = try(module.verified_access[0].instance_id, null)
}

output "eks_api_ava_domain" {
  description = "Use as the kubectl server address when Verified Access is enabled."
  value       = try(module.verified_access[0].endpoint_domain, null)
}

output "ava_endpoint_security_group_id" {
  description = "Owned solely by modules/verified-access."
  value       = try(module.verified_access[0].endpoint_security_group_id, null)
}

output "ava_custom_subdomain_name_servers" {
  description = "Delegate ava_custom_subdomain to these with an NS record, or the endpoint never resolves."
  value       = try(module.verified_access[0].custom_subdomain_name_servers, null)
}

output "ava_oidc_redirect_uri" {
  description = "Register this as an allowed callback URL on the OIDC application."
  value       = try(module.verified_access[0].oidc_redirect_uri, null)
}
