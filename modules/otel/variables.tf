variable "cluster_name" {
  type        = string
  description = "EKS cluster name for the ADOT addon"
}

variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "otel_collector_irsa_role_arn" {
  type        = string
  description = "IRSA role ARN for the OTel collector (from grafana module)"
}

variable "prometheus_endpoint" {
  type        = string
  description = "AMP remote write endpoint"
  default     = null
}

variable "opensearch_endpoint" {
  type        = string
  description = "OpenSearch domain endpoint (from elk module)"
  default     = null
}

variable "opensearch_username" {
  type      = string
  sensitive = true
}

variable "opensearch_password" {
  type      = string
  sensitive = true
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "observability" {
  type  = string
}
