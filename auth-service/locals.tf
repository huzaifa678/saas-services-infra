locals {
  db = jsondecode(data.aws_secretsmanager_secret_version.auth_db.secret_string)
}