resource "aws_iam_role_policy_attachment" "elk_prometheus" {
  role       = aws_iam_role.elk.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"
}

resource "aws_iam_role_policy_attachment" "otel_elk_amp_write" {
  role       = aws_iam_role.otel_collector_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
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

