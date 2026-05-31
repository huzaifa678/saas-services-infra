data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

# ── Interruption queue ───────────────────────────────────────────────────────────

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# ── EventBridge rules → interruption queue ──────────────────────────────────────

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${var.cluster_name}-karpenter-spot-interruption"
  description = "Karpenter: EC2 Spot Instance Interruption Warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${var.cluster_name}-karpenter-rebalance"
  description = "Karpenter: EC2 Instance Rebalance Recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule = aws_cloudwatch_event_rule.karpenter_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state" {
  name        = "${var.cluster_name}-karpenter-instance-state"
  description = "Karpenter: EC2 Instance State-change Notification"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state" {
  rule = aws_cloudwatch_event_rule.karpenter_instance_state.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  name        = "${var.cluster_name}-karpenter-scheduled-change"
  description = "Karpenter: AWS Health Event"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  rule = aws_cloudwatch_event_rule.karpenter_scheduled_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# ── IRSA: karpenter-controller ───────────────────────────────────────────────────

resource "aws_iam_role" "karpenter_irsa" {
  name               = "${var.cluster_name}-karpenter-irsa"
  assume_role_policy = local.pod_identity_assume_role
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name = "${var.cluster_name}-karpenter-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
        ]
        Resource = [
          "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:instance/*",
          "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:spot-instances-request/*",
          "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:security-group/*",
          "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:subnet/*",
          "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:launch-template/*",
          "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:volume/*",
          "arn:aws:ec2:*:${data.aws_caller_identity.this.account_id}:network-interface/*",
          "arn:aws:ec2:*::image/*",
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = data.aws_region.this.name
          }
        }
      },
      {
        Sid    = "AllowEC2ReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2MutatingActions"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
        }
      },
      {
        Sid      = "AllowInstanceProfileActions"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.karpenter_node_role.arn
      },
      {
        Sid    = "AllowInstanceProfileReadActions"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
        ]
        Resource = aws_iam_instance_profile.karpenter_node.arn
      },
      {
        Sid    = "AllowSQSInterruption"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid    = "AllowSSMAndPricing"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "pricing:GetProducts",
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEKSClusterAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
        ]
        Resource = "arn:aws:eks:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:cluster/${var.cluster_name}"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_attach" {
  role       = aws_iam_role.karpenter_irsa.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}

# ── Karpenter node role + instance profile ───────────────────────────────────────

resource "aws_iam_role" "karpenter_node_role" {
  name = "${var.cluster_name}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node-profile"
  role = aws_iam_role.karpenter_node_role.name
}

# ── EKS access entry for Karpenter nodes (must live in the EKS module, not in IAM,
#   because it references aws_eks_cluster.eks_cluster which is owned by the parent)

