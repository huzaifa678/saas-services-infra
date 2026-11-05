terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    "karpenter.sh/discovery" = var.cluster_name
    Name                     = "${var.cluster_name}-nodes-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "HTTPS egress to AWS service endpoints and the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "HTTP egress for package downloads"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "dns_udp" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "DNS egress (UDP)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "dns_tcp" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "DNS egress (TCP)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "intra_vpc" {
  security_group_id = aws_security_group.eks_nodes.id
  description       = "Node-to-node and node-to-data-tier communication within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  tags              = var.tags
}

# Allow ALL node-to-node / pod-to-pod traffic between any nodes carrying this SG.
# This SG is attached to BOTH the managed node group AND the Karpenter nodes, so a
# self-reference makes it the one shared path for cross-pool pod traffic. Without
# it, the pools share only this SG (which previously allowed just DNS/VXLAN/health),
# the managed-NG SG's self "allow-all" doesn't cover Karpenter nodes, and the
# cluster-primary SG is only on Karpenter nodes — so arbitrary pod ports (Crossplane
# function gRPC 9443, NGF control plane 443, Postgres 5432, Istio, etc.) between a
# managed node and a Karpenter node are dropped. This is standard EKS node-SG
# behaviour (nodes trust the node SG for all intra-cluster traffic). The narrower
# DNS/VXLAN/health rules below are now subsumed but kept for explicitness.
resource "aws_vpc_security_group_ingress_rule" "node_to_node_all" {
  security_group_id            = aws_security_group.eks_nodes.id
  description                  = "All node-to-node / pod-to-pod traffic within the cluster"
  referenced_security_group_id = aws_security_group.eks_nodes.id
  ip_protocol                  = "-1"
  tags                         = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "node_to_node_dns_tcp" {
  security_group_id            = aws_security_group.eks_nodes.id
  description                  = "Node-to-node DNS resolution (TCP)"
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "tcp"
  tags                         = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "node_to_node_dns_udp" {
  security_group_id            = aws_security_group.eks_nodes.id
  description                  = "Node-to-node DNS resolution (UDP)"
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "udp"
  tags                         = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "node_to_node_cilium_vxlan" {
  security_group_id            = aws_security_group.eks_nodes.id
  description                  = "Cilium VXLAN overlay (node-to-node)"
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  tags                         = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "node_to_node_cilium_health" {
  security_group_id            = aws_security_group.eks_nodes.id
  description                  = "Cilium health checks (node-to-node)"
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 4240
  to_port                      = 4240
  ip_protocol                  = "tcp"
  tags                         = var.tags
}
