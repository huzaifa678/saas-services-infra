resource "aws_iam_role" "grafana" {
  name = "${var.workspace_name}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "grafana.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_prometheus" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_role" "otel_collector_irsa" {
  name = "${var.workspace_name}-otel-collector-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_issuer, "https://", "")}:sub" = "system:serviceaccount:monitoring:otel-collector"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "otel_collector_amp_write" {
  role       = aws_iam_role.otel_collector_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
}

resource "aws_iam_role_policy_attachment" "otel_collector_xray_write" {
  role       = aws_iam_role.otel_collector_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "otel_collector_cloudwatch_write" {
  role       = aws_iam_role.otel_collector_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
