resource "helm_release" "keycloak" {
  name             = "keycloak"
  namespace        = "keycloak"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "keycloak"
  create_namespace = true
  timeout          = 600
  wait             = true

  set = [
    { name = "auth.adminUser",     value = "admin" },
    { name = "auth.adminPassword", value = "admin" },
    { name = "ingress.enabled",    value = "true" },
    { name = "ingress.ingressClassName", value = "nginx" },
    { name = "ingress.hostname",   value = "keycloak.local" },
    { name = "externalDatabase.host", value = module.rds_keycloak.endpoint },
    { name = "externalDatabase.port", value = "5436" },
  ]

  values = [file("${path.module}/values-keycloak.yaml")]

  depends_on = [
    var.eks_node_group,
    kubectl_manifest.gateway_api_crds
  ]
}
