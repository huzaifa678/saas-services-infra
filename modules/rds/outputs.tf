output "secret_arn" {
  description = "Custom secret holding {username,password,endpoint,db_name}. Parsed by the service roots."
  value       = aws_secretsmanager_secret.db.arn
}

output "endpoint" {
  value = module.db.db_instance_endpoint
}

output "instance_arn" {
  description = "RDS instance ARN. Consumed by the AWS Backup selection in layers/20-data."
  value       = module.db.db_instance_arn
}

output "instance_identifier" {
  value = module.db.db_instance_identifier
}

output "db_name" {
  value = module.db.db_instance_name
}

output "username" {
  value = var.db_username
}
