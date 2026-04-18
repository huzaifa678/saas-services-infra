resource "kubernetes_namespace_v1" "cert_manager" {
  provider = kubernetes.eks
  metadata {
    name = "cert-manager"
    labels = {
      "cert-manager.io/disable-validation" = "true"
    }
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  chart      = "cert-manager"
  repository = "oci://quay.io/jetstack/charts"
  version    = "v1.18.2"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  timeout    = 600
  wait       = true

  set = [
    { name = "crds.enabled", value = "true" },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = "cert-manager" },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = var.cert_manager_irsa_role_arn },
    { name = "config.enableGatewayAPI", value = "true" },
    { name = "startupapicheck.enabled", value = "false" }
  ]

  depends_on = [helm_release.nginx_gateway_fabric]
}
