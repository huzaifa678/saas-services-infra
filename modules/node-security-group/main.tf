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
