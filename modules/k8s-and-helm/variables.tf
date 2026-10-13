# no default variables set yet

variable "environment" {
  description = "Infra tier (dev|test|prod). Maps to the CD-repo env label (test -> staging)."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_ca" {
  type = string
}

variable "eks_node_group" {
  type = any
}

variable "auth_provider" {
  type = string
}

variable "keycloak_db_endpoint" {
  type    = string
  default = ""
}

variable "keycloak_hostname" {
  type    = string
  default = "keycloak.internal"
}

variable "auth0_issuer" {
  type    = string
  default = ""
}

variable "auth0_client_id" {
  type    = string
  default = ""
}

variable "auth0_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "observability" {
  type    = list(string)
  default = ["grafana"]
}

variable "karpenter_interruption_queue_name" {
  type = string
}
