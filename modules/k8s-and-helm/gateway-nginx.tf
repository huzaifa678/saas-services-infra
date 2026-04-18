data "kubectl_file_documents" "gateway_api_crds_docs" {
  content = file("${path.module}/gateway-api-crds.yaml")
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each  = data.kubectl_file_documents.gateway_api_crds_docs.manifests
  yaml_body = each.value
  wait      = true
}

resource "time_sleep" "wait_for_crds" {
  depends_on      = [kubectl_manifest.gateway_api_crds]
  create_duration = "60s"
}

resource "helm_release" "nginx_gateway_fabric" {
  name                       = "nginx-gateway-fabric"
  repository                 = "oci://ghcr.io/nginx/charts"
  chart                      = "nginx-gateway-fabric"
  namespace                  = "nginx-gateway"
  create_namespace           = true
  disable_openapi_validation = true
  timeout                    = 300
  wait                       = true

  set = [{
    name  = "nginxGateway.gwAPIExperimentalFeatures.enable"
    value = "false"
  }]

  depends_on = [
    time_sleep.wait_for_crds,
    helm_release.argocd
  ]
}
