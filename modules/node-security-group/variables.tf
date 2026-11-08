variable "cluster_name" {
  description = "EKS cluster name. Also the karpenter.sh/discovery tag value."
  type        = string
}

variable "vpc_id" {
  description = "VPC hosting the worker nodes."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, used to scope intra-VPC egress."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

# Contiguous NodePort block the internet-facing gateway Services pin (argocd /
# keycloak / backstage / grafana, http+https each). Kept tight so the NLB->NodePort
# ingress rule is narrow; MUST match the `nodePorts` values in the CD repo gateway
# charts. Defaults: 30100-30107 (8 ports = 4 gateways x {http,https}).
variable "gateway_nodeport_min" {
  description = "Lowest NodePort pinned by the gateway LoadBalancer Services."
  type        = number
  default     = 30100

  validation {
    condition     = var.gateway_nodeport_min >= 30000 && var.gateway_nodeport_min <= 32767
    error_message = "gateway_nodeport_min must be within the Kubernetes NodePort range 30000-32767."
  }
}

variable "gateway_nodeport_max" {
  description = "Highest NodePort pinned by the gateway LoadBalancer Services."
  type        = number
  default     = 30107

  validation {
    condition     = var.gateway_nodeport_max >= 30000 && var.gateway_nodeport_max <= 32767
    error_message = "gateway_nodeport_max must be within the Kubernetes NodePort range 30000-32767."
  }
}
