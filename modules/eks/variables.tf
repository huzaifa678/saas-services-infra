variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.32"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet IDs for the control plane ENIs and node groups"
}

variable "enable_public_access" {
  type        = bool
  description = "Allow the EKS API endpoint to be reachable publicly (dev only)"
  default     = false
}

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public API endpoint (ignored when public access is off)"
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the managed node group"
  default     = "t3.medium"
}

variable "desired_size" {
  type    = number
  default = 3
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 5
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for EKS secret envelope encryption"
}

variable "eks_nodes_sg_id" {
  type        = string
  description = "External node security group (from modules/node-security-group), attached to nodes so the data tier remains reachable"
}

variable "ebs_csi_role_arn" {
  type        = string
  description = "IAM role ARN for the aws-ebs-csi-driver addon"
}

# ── Cluster admin via access entries (not the creator-admin shortcut) ─────────
variable "cluster_admin_principal_arns" {
  type        = list(string)
  description = "Additional IAM principal ARNs to grant AmazonEKSClusterAdminPolicy via an access entry."
  default     = []
}

variable "include_caller_as_cluster_admin" {
  type        = bool
  description = <<-EOT
    Grant cluster admin to the IAM role running Terraform (resolved via
    aws_iam_session_context). This replaces bootstrap_cluster_creator_admin_
    permissions with an explicit, auditable access entry. Leaving this true keeps
    the deployer as an administrator; set it false only if cluster_admin_principal_
    arns already contains a valid, reachable admin.
  EOT
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}
