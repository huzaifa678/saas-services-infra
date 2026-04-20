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


data "kubectl_file_documents" "saas_manifest" {
    content = templatefile("${path.module}/argo-saas.yaml.tpl")
}

resource "kubectl_manifest" "saas_app" {
  yaml_body = data.kubectl_file_documents.saas_manifest.content
  wait      = true
  depends_on = [
    helm_release.argocd
  ]
}