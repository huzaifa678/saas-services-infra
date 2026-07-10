output "instance_id" {
  description = "Verified Access instance id."
  value       = aws_verifiedaccess_instance.this.id
}

output "endpoint_id" {
  description = "Verified Access endpoint id for the EKS API."
  value       = aws_verifiedaccess_endpoint.eks_api.id
}

output "endpoint_domain" {
  description = "DNS name of the Verified Access endpoint -- use this as the kubectl server address."
  value       = aws_verifiedaccess_endpoint.eks_api.endpoint_domain
}

output "endpoint_security_group_id" {
  description = "Security group attached to the AVA endpoint ENIs. This module is its sole owner."
  value       = aws_security_group.ava_endpoint.id
}

output "custom_subdomain_name_servers" {
  description = <<-EOT
    Delegate `cidr_endpoints_custom_subdomain` to these name servers with an NS
    record. Until you do, the cidr endpoint will not resolve and `kubectl` hangs
    rather than failing loudly.
  EOT
  value       = aws_verifiedaccess_instance.this.name_servers
}

output "group_id" {
  description = "Verified Access group id backing the EKS API endpoint."
  value       = aws_verifiedaccess_group.eks_api.verifiedaccess_group_id
}

output "oidc_redirect_uri" {
  description = "Register this as an allowed callback URL on the OIDC application."
  value       = "https://${aws_verifiedaccess_endpoint.eks_api.endpoint_domain}/oauth2/idpresponse"
}
