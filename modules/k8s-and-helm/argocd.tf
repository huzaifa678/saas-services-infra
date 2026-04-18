resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  create_namespace = true
  timeout          = 600
  wait             = true

  depends_on = [
    var.eks_node_group,
    kubectl_manifest.gateway_api_crds
  ]
}
