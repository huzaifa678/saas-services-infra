resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.name}-subnet-group" }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$&*"
  upper            = true
  lower            = true
  numeric          = true
}

resource "aws_db_instance" "this" {
  identifier          = var.name
  engine              = "postgres"
  engine_version      = "16.6"
  instance_class      = var.instance_class
  allocated_storage   = 20
  db_name             = var.db_name
  username            = var.db_username
  password            = coalesce(var.db_password, random_password.db_password.result)
  port                = tonumber(var.port)

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  
  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = var.name }
}
