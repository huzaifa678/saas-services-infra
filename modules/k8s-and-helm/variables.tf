# no default variables set yet

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

variable "vpc" {
  type = any
}

variable "vpc_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cert_manager_irsa_role_arn" {
  type = string
}

variable "external_dns_irsa_role_arn" {
  type = string
}

variable "aws_lb_controller_irsa_role_arn" {
  type = string
}
