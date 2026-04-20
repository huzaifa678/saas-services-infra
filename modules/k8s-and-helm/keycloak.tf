resource "helm_release" "keycloak" {
  count            = var.auth_provider == "keycloak" ? 1 : 0
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
    { name = "ingress.enabled",    value = "false" },
    { name = "externalDatabase.host", value = var.keycloak_db_endpoint },
    { name = "externalDatabase.port", value = "5436" },
  ]

  values = [file("${path.module}/values-keycloak.yaml")]

  depends_on = [
    var.eks_node_group,
    kubectl_manifest.gateway_api_crds
  ]
}

# Expose Keycloak via NGINX Gateway Fabric (Gateway API)
resource "kubectl_manifest" "keycloak_gateway" {
  count = var.auth_provider == "keycloak" ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: keycloak-gateway
      namespace: keycloak
    spec:
      gatewayClassName: nginx
      listeners:
        - name: https
          port: 443
          protocol: HTTPS
          hostname: "${var.keycloak_hostname}"
          tls:
            mode: Terminate
            certificateRefs:
              - name: keycloak-tls
                kind: Secret
  YAML

  depends_on = [helm_release.keycloak]
}

resource "kubectl_manifest" "keycloak_httproute" {
  count = var.auth_provider == "keycloak" ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: keycloak
      namespace: keycloak
    spec:
      parentRefs:
        - name: keycloak-gateway
      hostnames:
        - "${var.keycloak_hostname}"
      rules:
        - backendRefs:
            - name: keycloak
              port: 80
  YAML

  depends_on = [kubectl_manifest.keycloak_gateway]
}

# Auth0 credentials for keycloak-config-cli identity provider brokering
resource "kubernetes_secret" "keycloak_auth0" {
  count = var.auth_provider == "keycloak" ? 1 : 0

  metadata {
    name      = "keycloak-auth0-secret"
    namespace = "keycloak"
  }

  data = {
    AUTH0_ISSUER        = var.auth0_issuer
    AUTH0_CLIENT_ID     = var.auth0_client_id
    AUTH0_CLIENT_SECRET = var.auth0_client_secret
  }

  depends_on = [helm_release.keycloak]
}
