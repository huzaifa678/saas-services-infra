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
  content = templatefile("${path.module}/argo-saas.yaml.tpl", {
    env = local.env
  })
}

resource "kubectl_manifest" "saas_app" {
  yaml_body  = data.kubectl_file_documents.saas_manifest.content
  wait       = true
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "cert_manager_app" {
  yaml_body  = file("${path.module}/argo-cert-manager.yaml.tpl")
  wait       = true
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "external_dns_app" {
  yaml_body  = file("${path.module}/argo-external-dns.yaml.tpl")
  wait       = true
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "external_secrets_app" {
  yaml_body  = file("${path.module}/argo-external-secrets.yaml.tpl")
  wait       = true
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "keycloak_app" {
  count = var.auth_provider == "keycloak" ? 1 : 0
  yaml_body = templatefile("${path.module}/argo-keycloak.yaml.tpl", {
    keycloak_db_endpoint = var.keycloak_db_endpoint
  })
  wait       = true
  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "karpenter_app" {
  yaml_body = templatefile("${path.module}/argo-karpenter.yaml.tpl", {
    cluster_name                      = var.cluster_name
    karpenter_interruption_queue_name = var.karpenter_interruption_queue_name
  })
  wait       = true
  depends_on = [helm_release.argocd]
}
