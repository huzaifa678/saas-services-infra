locals {
  db  = jsondecode(data.aws_secretsmanager_secret_version.usage_db.secret_string)
  llm = jsondecode(data.aws_secretsmanager_secret_version.llm.secret_string)
}
