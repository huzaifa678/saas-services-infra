locals {
  api_input = jsondecode(
    data.aws_secretsmanager_secret_version.api_gateway_input.secret_string
  )
}
