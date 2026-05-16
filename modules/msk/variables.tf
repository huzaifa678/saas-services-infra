variable "cluster_name" {
  type    = string
  default = "saas-msk"
}

variable "kafka_version" {
  type    = string
  default = "3.7.x.kraft" 
}

variable "number_of_broker_nodes" {
  type    = number
  default = 2
}

variable "broker_instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "broker_volume_size" {
  type    = number
  default = 20
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs (must match number_of_broker_nodes)"
}

variable "msk_sg_id" {
  type = string
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for MSK at-rest encryption"
}
