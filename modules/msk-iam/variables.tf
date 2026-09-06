variable "name" {
  type        = string
  description = "Name prefix for the IAM role and policy (typically <cluster>-<workload>)."
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster hosting the workload, for the Pod Identity association."
}

variable "msk_cluster_arn" {
  type        = string
  description = "ARN of the MSK cluster the workload connects to. Topic/group ARNs are derived from it."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the workload's ServiceAccount."
}

variable "service_account" {
  type        = string
  description = "Kubernetes ServiceAccount name the pod runs as."
}

variable "topics" {
  type        = list(string)
  description = "Topic names (within this cluster) the workload may describe/read/write. Defaults to all topics on the cluster."
  default     = ["*"]
}

variable "consumer_groups" {
  type        = list(string)
  description = "Consumer group names the workload may join. Defaults to all groups on the cluster."
  default     = ["*"]
}

variable "tags" {
  type        = map(string)
  description = "Common tags."
  default     = {}
}
