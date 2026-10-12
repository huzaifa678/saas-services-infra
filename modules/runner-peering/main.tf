terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

# ===========================================================================
# Connects the isolated runner VPC to an application VPC so the runner can reach
# the private EKS API (for the kubectl layers 45-rbac / 50-addons-helm and the
# cluster-bootstrap workflow). Same account + region, so the peering auto-accepts.
#
# Three things are required for the kubectl provider to actually work across the
# peering:
#   1. the peering connection,
#   2. routes in BOTH VPCs (runner -> app CIDR, app -> runner CIDR),
#   3. DNS: cross-VPC resolution over the peering, so the EKS private endpoint
#      FQDN resolves to the private ENIs from the runner side (see below for why
#      the zone can't simply be associated).
# Plus a 443 ingress on the cluster security group from the runner CIDR.
# ===========================================================================

resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.runner_vpc_id # requester
  peer_vpc_id = var.app_vpc_id    # accepter (same account/region)
  auto_accept = true

  tags = merge(var.tags, { Name = "${var.name}-runner-to-app" })
}

# Runner private subnet -> application VPC.
resource "aws_route" "runner_to_app" {
  route_table_id            = var.runner_route_table_id
  destination_cidr_block    = var.app_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Application private subnets -> runner VPC (return path).
resource "aws_route" "app_to_runner" {
  for_each = toset(var.app_route_table_ids)

  route_table_id            = each.value
  destination_cidr_block    = var.runner_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# Allow the runner CIDR to reach the EKS API on 443 via the cluster security group.
resource "aws_vpc_security_group_ingress_rule" "api_from_runner" {
  security_group_id = var.cluster_security_group_id
  description       = "EKS API (443) from the peered CI runner VPC"
  cidr_ipv4         = var.runner_vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = var.tags
}

# ── Private DNS ──────────────────────────────────────────────────────────────
# Let the runner VPC resolve the private EKS API FQDN (so `aws eks get-token` +
# kubectl hit the private ENIs). Modern EKS puts the API endpoint's private
# hosted zone in an AWS-SERVICE-OWNED account (Owner.OwningService =
# eks.amazonaws.com) and associates it with the cluster VPC; it is NOT visible in
# this account and cannot be looked up or associated with another VPC. So instead
# of associating the zone, we turn on cross-VPC DNS resolution over the peering:
# with accepter (app VPC) resolution enabled, queries from the requester (runner)
# VPC resolve against the private hosted zones associated with the app VPC,
# including that service-owned EKS zone. Disable to manage DNS out-of-band.
resource "aws_vpc_peering_connection_options" "this" {
  count = var.enable_peering_dns_resolution ? 1 : 0

  vpc_peering_connection_id = aws_vpc_peering_connection.this.id

  # App VPC side (accepter): allow the peer (runner) VPC to resolve the app VPC's
  # private DNS, i.e. the EKS private endpoint.
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}
