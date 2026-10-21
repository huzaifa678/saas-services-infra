resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  create_namespace = true
  timeout          = 600
  wait             = true

  # Do NOT let the chart create its per-component NetworkPolicies. 
  values = [yamlencode({
    global = {
      networkPolicy = {
        create = false
      }
    }
  })]

  depends_on = [
    var.eks_node_group
  ]
}

data "kubectl_file_documents" "saas_manifest" {
  content = templatefile("${path.module}/argo-saas.yaml.tpl", {
    env           = local.env
    stack_grafana = local.stack_grafana
    stack_elk     = local.stack_elk
  })
}

resource "kubectl_manifest" "saas_app" {
  for_each   = data.kubectl_file_documents.saas_manifest.manifests
  yaml_body  = each.value
  wait       = true
  depends_on = [helm_release.argocd]
}

# cert-manager and external-dns are no longer bootstrapped from Terraform — both
# were migrated to the CD repo's addons ApplicationSet (gitops/infra/cert-manager,
# gitops/infra/external-dns), now running as cert-manager-<env> / external-dns-<env>.
# The old Applications here (upstream charts) sat Unknown/OutOfSync and, for
# external-dns, a second controller fought the new one over the same DNS records.
# Removing both bootstraps; the CD addons own them.
# NOTE (operational): no ArgoCD deletion finalizer here, so removing these only
# orphans (does not prune) — delete the leftover `cert-manager` and `external-dns`
# Applications from the cluster once so they stop showing as duplicates.

resource "kubectl_manifest" "keycloak_app" {
  count = var.auth_provider == "keycloak" ? 1 : 0
  yaml_body = templatefile("${path.module}/argo-keycloak.yaml.tpl", {
    keycloak_db_endpoint = var.keycloak_db_endpoint
  })
  wait       = true
  depends_on = [helm_release.argocd]
}

# karpenter is no longer bootstrapped from Terraform — it was migrated to the CD
# repo's addons ApplicationSet (gitops/infra/karpenter, delivered via the eso
# karpenter-contract Secret for clusterName/interruptionQueue). The old Application
# here pinned oci://public.ecr.aws/karpenter 1.4.0, which now 404s and left the
# karpenter app stuck in ComparisonError. Removing this bootstrap; the live
# controller is owned by karpenter-<env>.
# NOTE (operational): this resource has no ArgoCD deletion finalizer, so removing it
# only orphans (does not prune) — delete the leftover karpenter Application from
# the cluster once. var.karpenter_interruption_queue_name is now unused in this
# module (still wired from the layer); prune it in a later cleanup if desired.
