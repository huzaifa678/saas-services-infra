resource "aws_grafana_workspace" "this" {
  name                     = var.workspace_name
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = [
    "PROMETHEUS",
    "CLOUDWATCH",
    "XRAY"
  ]

  tags = { Name = var.workspace_name }
}

resource "aws_prometheus_workspace" "this" {
  alias = "${var.workspace_name}-prometheus"
  tags  = { Name = "${var.workspace_name}-prometheus" }
}
