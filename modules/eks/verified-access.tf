# ─── AWS Verified Access — Zero Trust proxy for private EKS API (prod only) ──
# Traffic flow: client → AVA endpoint (public) → Auth0 OIDC authn/authz
#               → private EKS API endpoint (no VPN required)

resource "aws_verifiedaccess_trust_provider" "auth0" {
  count                    = var.enable_verified_access ? 1 : 0
  trust_provider_type      = "user"
  user_trust_provider_type = "oidc"
  description              = "Auth0 OIDC trust provider for ${var.cluster_name}"

  oidc_options {
    issuer                 = var.ava_oidc_issuer
    authorization_endpoint = "${var.ava_oidc_issuer}/authorize"
    token_endpoint         = "${var.ava_oidc_issuer}/oauth/token"
    user_info_endpoint     = "${var.ava_oidc_issuer}/userinfo"
    client_id              = var.ava_oidc_client_id
    client_secret          = var.ava_oidc_client_secret
    scope                  = "openid profile email"
  }

  policy_reference_name = "auth0"

  tags = { Name = "${var.cluster_name}-ava-trust-provider" }
}

resource "aws_verifiedaccess_instance" "this" {
  count       = var.enable_verified_access ? 1 : 0
  description = "Verified Access instance for ${var.cluster_name}"
  tags        = { Name = "${var.cluster_name}-ava-instance" }
}

resource "aws_verifiedaccess_instance_trust_provider_attachment" "this" {
  count                               = var.enable_verified_access ? 1 : 0
  verifiedaccess_instance_id          = aws_verifiedaccess_instance.this[0].id
  verifiedaccess_trust_provider_id    = aws_verifiedaccess_trust_provider.auth0[0].id
}

resource "aws_verifiedaccess_group" "eks" {
  count                      = var.enable_verified_access ? 1 : 0
  verifiedaccess_instance_id = aws_verifiedaccess_instance.this[0].id
  description                = "EKS API access group"

  policy_document = <<-EOT
    permit(principal, action, resource)
    when { true };
  EOT

  tags = { Name = "${var.cluster_name}-ava-group" }

  depends_on = [aws_verifiedaccess_instance_trust_provider_attachment.this]
}

# SG for the AVA endpoint ENIs — allows HTTPS inbound from anywhere,
# forwards to the private EKS API endpoint inside the VPC
resource "aws_security_group" "ava_endpoint_sg" {
  count       = var.enable_verified_access ? 1 : 0
  name        = "${var.cluster_name}-ava-endpoint-sg"
  description = "Verified Access endpoint — HTTPS inbound, EKS API forward"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Forward to EKS API"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = [var.vpc_cidr]
  }

  tags = { Name = "${var.cluster_name}-ava-endpoint-sg" }
}

resource "aws_verifiedaccess_endpoint" "eks_api" {
  count = var.enable_verified_access ? 1 : 0

  verified_access_group_id = aws_verifiedaccess_group.eks[0].id

  endpoint_type   = "network-interface"
  attachment_type = "vpc"

  description = "Private EKS API endpoint"

  security_group_ids = [aws_security_group.ava_endpoint_sg[0].id]
}