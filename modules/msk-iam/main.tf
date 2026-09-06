terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

# Binds one Kubernetes ServiceAccount to a least-privilege MSK IAM role via EKS
# Pod Identity. The pod assumes the role through pods.eks.amazonaws.com — no
# static credentials — and authenticates to the cluster with SASL/IAM. This is
# what turns the cluster's SASL/IAM posture into something workloads can use.

locals {
  topic_prefix = replace(var.msk_cluster_arn, ":cluster/", ":topic/")
  group_prefix = replace(var.msk_cluster_arn, ":cluster/", ":group/")

  assume_role = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-msk"
  assume_role_policy = local.assume_role
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  name = "${var.name}-msk"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ClusterConnect"
        Effect   = "Allow"
        Action   = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster"]
        Resource = var.msk_cluster_arn
      },
      {
        Sid      = "Topics"
        Effect   = "Allow"
        Action   = ["kafka-cluster:DescribeTopic", "kafka-cluster:ReadData", "kafka-cluster:WriteData"]
        Resource = [for t in var.topics : "${local.topic_prefix}/${t}"]
      },
      {
        Sid      = "Groups"
        Effect   = "Allow"
        Action   = ["kafka-cluster:AlterGroup", "kafka-cluster:DescribeGroup"]
        Resource = [for g in var.consumer_groups : "${local.group_prefix}/${g}"]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.eks_cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.this.arn
  tags            = var.tags
}
