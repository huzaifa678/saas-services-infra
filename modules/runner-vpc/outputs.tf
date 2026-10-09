output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "The runner's private subnet(s) — vpc_zone_identifier for the ASG."
  value       = [aws_subnet.private.id]
}

output "private_route_table_id" {
  description = "Private route table the peering module adds the app-VPC route to."
  value       = aws_route_table.private.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public.id]
}

output "nat_public_ip" {
  description = "Stable egress IP of the runner VPC."
  value       = aws_eip.nat.public_ip
}
