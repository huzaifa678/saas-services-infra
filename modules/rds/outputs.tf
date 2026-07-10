output "secret_arn" {
  description = "Custom secret holding {username,password,endpoint,db_name}. Parsed by the service roots."
  value       = aws_secretsmanager_secret.db.arn
}

output "endpoint" {
  value = module.db.db_instance_endpoint
}

output "db_name" {
  value = module.db.db_instance_name
}

output "username" {
  value = var.db_username
}
