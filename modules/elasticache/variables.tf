variable "name" {
  type    = string
  default = "saas-redis"
}

variable "node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "subnet_ids" {
  type = list(string)
}

variable "redis_sg_id" {
  type = string
}
