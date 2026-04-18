resource "helm_release" "external_dns" {
  name             = "external-dns"
  chart            = "external-dns"
  namespace        = "external-dns"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  timeout          = 300
  wait             = true

  set = [
    { name = "provider.name", value = "aws" },
    { name = "provider.aws.zoneType", value = "public" },
    { name = "policy", value = "sync" },
    { name = "registry", value = "txt" },
    { name = "txtOwnerId", value = "terraform" },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = "external-dns" },
    { name = "rbac.create", value = "true" },
    { name = "sources[0]", value = "gateway-httproute" },
    { name = "sources[1]", value = "gateway-grpcroute" },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = var.external_dns_irsa_role_arn },
    { name = "managedRecordTypes[0]", value = "CNAME" },
    { name = "managedRecordTypes[1]", value = "A" }
  ]

  depends_on = [
    helm_release.nginx_gateway_fabric,
    helm_release.cert_manager
  ]
}
