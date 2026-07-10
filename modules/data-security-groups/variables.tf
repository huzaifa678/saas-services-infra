variable "cluster_name" {
  description = "EKS cluster name, used as the security group name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC hosting the data tier."
  type        = string
}

variable "eks_nodes_sg_id" {
  description = <<-EOT
    Security group of the EKS worker nodes -- the only permitted ingress source for
    every data-tier security group. Comes from the platform layer's remote state.
  EOT
  type        = string
}

variable "msk_tls_enabled" {
  description = "Open MSK broker port 9094 (TLS mutual auth)."
  type        = bool
  default     = true
}

variable "msk_sasl_scram_enabled" {
  description = "Open MSK broker port 9096 (SASL/SCRAM). Driven by guardrails."
  type        = bool
  default     = false
}

variable "msk_sasl_iam_enabled" {
  description = "Open MSK broker port 9098 (SASL/IAM). Driven by guardrails."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
