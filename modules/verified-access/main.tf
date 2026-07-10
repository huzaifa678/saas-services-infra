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
  oidc = {
    authorization_endpoint = coalesce(
      try(var.oidc_endpoint_overrides.authorization_endpoint, null),
      "${var.oidc_issuer}/authorize",
    )
    token_endpoint = coalesce(
      try(var.oidc_endpoint_overrides.token_endpoint, null),
      "${var.oidc_issuer}/oauth/token",
    )
    user_info_endpoint = coalesce(
      try(var.oidc_endpoint_overrides.user_info_endpoint, null),
      "${var.oidc_issuer}/userinfo",
    )
  }

  policy_reference_name = "oidc"
}

resource "aws_verifiedaccess_instance" "this" {
  description = "${var.name_prefix} zero-trust access plane"

  cidr_endpoints_custom_subdomain = var.cidr_endpoints_custom_subdomain
  fips_enabled                    = var.fips_enabled

  tags = merge(var.tags, { Name = "${var.name_prefix}-ava" })
}

resource "aws_verifiedaccess_trust_provider" "oidc" {
  description = "OIDC trust provider ${var.oidc_issuer}"

  trust_provider_type      = "user"
  user_trust_provider_type = "oidc"
  policy_reference_name    = local.policy_reference_name

  oidc_options {
    issuer                 = var.oidc_issuer
    authorization_endpoint = local.oidc.authorization_endpoint
    token_endpoint         = local.oidc.token_endpoint
    user_info_endpoint     = local.oidc.user_info_endpoint
    client_id              = var.oidc_client_id
    client_secret          = var.oidc_client_secret
    scope                  = var.oidc_scope
  }

  sse_specification {
    customer_managed_key_enabled = true
    kms_key_arn                  = var.kms_key_arn
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ava-trust-provider" })
}

resource "aws_verifiedaccess_instance_trust_provider_attachment" "this" {
  verifiedaccess_instance_id       = aws_verifiedaccess_instance.this.id
  verifiedaccess_trust_provider_id = aws_verifiedaccess_trust_provider.oidc.id
}

resource "aws_verifiedaccess_group" "eks_api" {
  verifiedaccess_instance_id = aws_verifiedaccess_instance.this.id
  description                = "${var.name_prefix} EKS API access group"
  policy_document            = var.policy_document

  sse_configuration {
    customer_managed_key_enabled = true
    kms_key_arn                  = var.kms_key_arn
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ava-eks-api" })

  # The group's policy references the trust provider's policy_reference_name, so
  # the attachment must exist before the policy can be evaluated.
  depends_on = [aws_verifiedaccess_instance_trust_provider_attachment.this]
}

# Ingress is 443 from the internet by design: this endpoint *is* the public front
# door, and every request is authenticated by the OIDC trust provider and
# authorised by the Cedar policy before it is forwarded. Egress is constrained to
# the EKS API range only.
resource "aws_security_group" "ava_endpoint" {
  name        = "${var.name_prefix}-ava-endpoint-sg"
  description = "Verified Access endpoint -- HTTPS inbound, forwards to private EKS API"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-ava-endpoint-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ava_https" {
  security_group_id = aws_security_group.ava_endpoint.id
  description       = "HTTPS from internet, terminated and authenticated by AVA"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "ava_to_eks_api" {
  security_group_id = aws_security_group.ava_endpoint.id
  description       = "Forward to the private EKS API endpoint"
  cidr_ipv4         = var.eks_api_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = var.tags
}

# A `cidr` endpoint, not `network-interface`. The previous implementation declared
# endpoint_type = "network-interface" with no network_interface_options block,
# which the provider rejects, and never consumed the subnet ids it was passed.
resource "aws_verifiedaccess_endpoint" "eks_api" {
  verified_access_group_id = aws_verifiedaccess_group.eks_api.verifiedaccess_group_id
  description              = "${var.name_prefix} private EKS API endpoint"

  attachment_type    = "vpc"
  endpoint_type      = "cidr"
  security_group_ids = [aws_security_group.ava_endpoint.id]

  cidr_options {
    cidr       = var.eks_api_cidr
    protocol   = "tcp"
    subnet_ids = var.endpoint_subnet_ids

    port_range {
      from_port = 443
      to_port   = 443
    }
  }

  sse_specification {
    customer_managed_key_enabled = true
    kms_key_arn                  = var.kms_key_arn
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ava-eks-api-endpoint" })
}

resource "aws_cloudwatch_log_group" "ava" {
  count = var.logging_enabled ? 1 : 0

  name              = "/aws/verified-access/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_verifiedaccess_instance_logging_configuration" "this" {
  count = var.logging_enabled ? 1 : 0

  verifiedaccess_instance_id = aws_verifiedaccess_instance.this.id

  access_logs {
    include_trust_context = var.log_include_trust_context
    log_version           = "ocsf-1.1.0"

    cloudwatch_logs {
      enabled   = true
      log_group = aws_cloudwatch_log_group.ava[0].name
    }
  }
}
