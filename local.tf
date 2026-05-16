locals {
  ordered_public_subnets  = sort(var.public_subnets)
  ordered_private_subnets = sort(var.private_subnets)
}

locals {
  services = ["api-gateway", "auth-service", "subscription-service", "billing-service", "usage-service"]
}