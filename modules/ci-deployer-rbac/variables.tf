variable "manifest_path" {
  description = "Absolute path to the ci-deployer RBAC manifest template (multi-document YAML)."
  type        = string
}

variable "deployer_group" {
  description = "Kubernetes group the RBAC binds; the steady-state deployer's EKS access entry maps its role to this group."
  type        = string
  default     = "saas:ci-deployers"
}

# Namespaces the deployer installs platform charts into and must fully control,
# but which do NOT pre-exist — the manifest creates the namespace and a `*` Role.
# Defaults are the 50-addons-helm install targets: argocd (Argo CD + the app-of-apps
# CRs), nginx-gateway (NGINX Gateway Fabric), monitoring (the OTel collector CR).
variable "provisioned_namespaces" {
  description = "Namespaces the ci-deployer both creates and gets full (namespaced) control of."
  type        = list(string)
  default     = ["argocd", "nginx-gateway", "monitoring"]
}

# Namespaces that already exist (not created here) but where the deployer still
# needs full control — e.g. kube-system, where the AWS Load Balancer Controller
# chart installs. A `*` Role is granted; the namespace object is left untouched.
variable "existing_admin_namespaces" {
  description = "Pre-existing namespaces the ci-deployer gets full (namespaced) control of without creating them."
  type        = list(string)
  default     = ["kube-system"]
}
