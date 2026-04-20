locals {
  db = jsondecode(data.aws_secretsmanager_secret_version.billing_db.secret_string)
}