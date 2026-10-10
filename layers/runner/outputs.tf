output "runner_app_key_secret_arn" {
  description = "Seed the GitHub App private key (PEM) here (out-of-band, once), then cycle the ASG."
  value       = module.runner.app_key_secret_arn
}

output "runner_asg_name" {
  description = "Runner ASG name, for cycling the instance after seeding the App key."
  value       = module.runner.asg_name
}

output "runner_vpc_id" {
  value = module.vpc.vpc_id
}

output "runner_nat_public_ip" {
  description = "Stable egress IP of the runner VPC."
  value       = module.vpc.nat_public_ip
}

output "peering_connection_id" {
  value = module.peering.peering_connection_id
}
