terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

locals {
  tiers = {
    rds        = "RDS PostgreSQL instances"
    redis      = "ElastiCache Redis"
    msk        = "MSK Kafka brokers"
    opensearch = "OpenSearch domain"
  }

  # Single-port tiers. MSK is handled separately because it admits a discrete set
  # of broker ports rather than a contiguous range.
  simple_ports = {
    rds        = 5432
    redis      = 6379
    opensearch = 443
  }

  # Only the broker ports the enabled auth mechanisms actually listen on. 9092 is
  # the plaintext listener and is never opened -- guardrails mandates TLS, and the
  # previous 9092-9096 range contradicted that.
  msk_ports = toset(compact([
    var.msk_tls_enabled ? "9094" : "",
    var.msk_sasl_scram_enabled ? "9096" : "",
    var.msk_sasl_iam_enabled ? "9098" : "",
  ]))
}

resource "aws_security_group" "this" {
  for_each = local.tiers

  name        = "${var.cluster_name}-${each.key}-sg"
  description = "Security group for ${each.value}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-${each.key}-sg" })

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = each.key != "msk" || length(local.msk_ports) > 0
      error_message = "MSK has no enabled auth mechanism, so no broker port could be opened. Enable TLS, SASL/SCRAM, or SASL/IAM."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_eks_nodes" {
  for_each = local.simple_ports

  security_group_id            = aws_security_group.this[each.key].id
  description                  = "Allow EKS nodes to reach ${local.tiers[each.key]}"
  referenced_security_group_id = var.eks_nodes_sg_id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "msk_from_eks_nodes" {
  for_each = local.msk_ports

  security_group_id            = aws_security_group.this["msk"].id
  description                  = "Allow EKS nodes to reach MSK broker port ${each.value}"
  referenced_security_group_id = var.eks_nodes_sg_id
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  ip_protocol                  = "tcp"

  tags = var.tags
}
