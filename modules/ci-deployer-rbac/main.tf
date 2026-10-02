terraform {
  required_version = ">= 1.3.0"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

# ci-deployer RBAC — the least-privilege identity the steady-state deployer runs
# as inside the cluster. It grants exactly what GitOps bootstrap needs: manage
# namespaces + CRDs, and manage ClusterRoles/Bindings *including* bind+escalate
# (so it can install ArgoCD's own roles), plus full control of the argocd
# namespace. It is NOT cluster-admin.
#
# Kubernetes escalation-prevention: creating a ClusterRole that itself holds
# bind/escalate requires a caller who already has those verbs — i.e. a
# cluster-admin. So the FIRST apply of this manifest must run as the gated
# cluster-bootstrap principal (or the human admin running the one-time bootstrap).
# After it exists, the tf-apply role (mapped to var.deployer_group) reconciles the
# cluster forever without ever being cluster-admin.
data "kubectl_file_documents" "ci_deployer" {
  content = templatefile("${var.manifest_path}", {
    deployer_group = var.deployer_group
  })
}

resource "kubectl_manifest" "ci_deployer" {
  for_each  = data.kubectl_file_documents.ci_deployer.manifests
  yaml_body = each.value
  wait      = true
}
