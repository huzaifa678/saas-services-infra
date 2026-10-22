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

# keycloak is no longer bootstrapped from Terraform — this was the Bitnami keycloak
# chart (charts.bitnami.com/bitnami, targetRevision "*"), whose images Docker Hub
# removed in the Aug 2025 Bitnami deprecation (docker.io/bitnami/keycloak → 404,
# ImagePullBackOff) and which folded the RDS host:port into one field. Keycloak is
# now owned by the CD repo's keycloakx addon (gitops/infra/keycloak → `keycloak-staging`,
# official quay.io/keycloak image, same RDS via the keycloak-contract Secret).
# NOTE (operational): no ArgoCD deletion finalizer here, so removing this only orphans
# (does not prune) — delete the leftover `keycloak-helm` Application and its
# keycloak-0 / keycloak-postgresql-0 from the cluster once. var.keycloak_db_endpoint /
# var.auth_provider are now unused in this module; prune in a later cleanup.

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
