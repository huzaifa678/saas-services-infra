locals {
  db = jsondecode(data.aws_secretsmanager_secret_version.subscription_db.secret_string)
}
