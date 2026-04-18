variable "name" {
  type        = string
  description = "RDS instance identifier"
}

variable "db_name" {
  type        = string
  description = "Database name"
}

variable "db_username" {
  type        = string
  description = "Database master username"
}

variable "db_password" {
  type        = string
  description = "Database master password (generated if null)"
  default     = null
  sensitive   = true
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group"
}

variable "rds_sg_id" {
  type        = string
  description = "Security group ID for RDS"
}

variable "port" {
  type = string
  description = "Port number for DB"
}
