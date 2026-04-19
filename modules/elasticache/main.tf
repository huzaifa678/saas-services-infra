resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.name}-subnet-group" }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.name
  description                = "Redis cluster for SAAS services"
  engine                     = "redis"
  engine_version             = "7.0"
  node_type                  = var.node_type
  num_node_groups            = 1
  replicas_per_node_group    = 0
  automatic_failover_enabled = false
  multi_az_enabled           = false
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.redis_sg_id]
  port                       = 6379
  parameter_group_name       = "default.redis7"
  apply_immediately          = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn

  tags = { Name = var.name }
}
