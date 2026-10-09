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
#   3. DNS: associate the EKS private hosted zone with the runner VPC, else the
#      API endpoint FQDN won't resolve to the private ENIs from the runner side.
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
# Associate the EKS-managed private hosted zone (named after the API endpoint
# FQDN) with the runner VPC so `aws eks get-token` + kubectl resolve the private
# ENIs. Default: derive the zone name from the endpoint; override if EKS named it
# differently. Set associate_eks_private_zone=false to manage DNS out-of-band.
locals {
  derived_zone_name = replace(replace(var.cluster_endpoint, "https://", ""), "/", "")
  zone_name         = var.eks_private_zone_name != "" ? var.eks_private_zone_name : local.derived_zone_name
}

data "aws_route53_zone" "eks_private" {
  count = var.associate_eks_private_zone ? 1 : 0

  name         = local.zone_name
  private_zone = true
  vpc_id       = var.app_vpc_id
}

resource "aws_route53_zone_association" "runner" {
  count = var.associate_eks_private_zone ? 1 : 0

  zone_id = data.aws_route53_zone.eks_private[0].zone_id
  vpc_id  = var.runner_vpc_id
}
