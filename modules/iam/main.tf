locals {
  pod_identity_assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_policy" "route53_policy" {
  name = "${var.cluster_name}-route53-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "route53:ChangeResourceRecordSets",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:GetChange",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "cert_manager_irsa" {
  name               = "${var.cluster_name}-cert-manager-irsa"
  assume_role_policy = local.pod_identity_assume_role
}

resource "aws_iam_role_policy_attachment" "cert_manager_route53" {
  role       = aws_iam_role.cert_manager_irsa.name
  policy_arn = aws_iam_policy.route53_policy.arn
}

resource "aws_iam_role" "external_dns_irsa" {
  name               = "${var.cluster_name}-external-dns-irsa"
  assume_role_policy = local.pod_identity_assume_role
}

resource "aws_iam_role_policy_attachment" "external_dns_route53" {
  role       = aws_iam_role.external_dns_irsa.name
  policy_arn = aws_iam_policy.route53_policy.arn
}

resource "aws_iam_role" "external_secrets_irsa" {
  name               = "${var.cluster_name}-external-secrets-irsa"
  assume_role_policy = local.pod_identity_assume_role
}

resource "aws_iam_policy" "external_secrets_policy" {
  name = "${var.cluster_name}-external-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets_attach" {
  role       = aws_iam_role.external_secrets_irsa.name
  policy_arn = aws_iam_policy.external_secrets_policy.arn
}

resource "aws_iam_role" "aws_lb_controller_irsa" {
  name               = "${var.cluster_name}-aws-lb-controller-irsa"
  assume_role_policy = local.pod_identity_assume_role
}

resource "aws_iam_policy" "aws_lb_controller_policy" {
  name = "${var.cluster_name}-aws-lb-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags",
        "ec2:DescribeRouteTables",
        "ec2:DescribeAvailabilityZones",
        "ec2:ModifyNetworkInterfaceAttribute",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "elasticloadbalancing:*",
        "iam:PassRole",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach" {
  policy_arn = aws_iam_policy.aws_lb_controller_policy.arn
  role       = aws_iam_role.aws_lb_controller_irsa.name
}

# ── EBS CSI driver (Pod Identity) ────────────────────────────────────────────────

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-irsa"
  assume_role_policy = local.pod_identity_assume_role
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
