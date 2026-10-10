locals {
  input = jsondecode(
    data.aws_secretsmanager_secret_version.backstage_input.secret_string
  )
}
