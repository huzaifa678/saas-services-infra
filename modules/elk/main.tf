resource "aws_prometheus_workspace" "this" {
  alias = "${var.domain_name}-elk-prometheus"
  tags  = {
    Name = "${var.domain_name}-elk-prometheus"
    Stack = "elk"
  }
}

resource "aws_iam_role_policy_attachment" "elk_prometheus" {
  role       = aws_iam_role.elk.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"
}

resource "aws_iam_role_policy_attachment" "otel_elk_amp_write" {
  role       = aws_iam_role.otel_collector_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
}

resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    zone_awareness_enabled = false
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.volume_size
  }

  vpc_options {
    subnet_ids         = [var.subnet_ids[0]]
    security_group_ids = [var.opensearch_sg_id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = true
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = var.master_user_password
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "es:*"
      Resource  = "arn:aws:es:*:*:domain/${var.domain_name}/*"
    }]
  })

  tags = { Name = var.domain_name }
}

resource "aws_iam_role" "elk" {
  name = "${var.domain_name}-elk-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "opensearchservice.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "elk_opensearch_access" {
  role       = aws_iam_role.elk.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonOpenSearchServiceFullAccess"
}

resource "aws_iam_policy" "otel_opensearch_write" {
  name = "otel-opensearch-write"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "es:ESHttpPost",
        "es:ESHttpPut",
        "es:ESHttpPatch"
      ]
      Resource = "arn:aws:es:*:*:domain/${var.domain_name}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "otel_opensearch_write" {
  role       = aws_iam_role.otel_collector_irsa.name
  policy_arn = aws_iam_policy.otel_opensearch_write.arn
}
