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
# as inside the cluster. It grants exactly what the GitOps/addons bootstrap needs:
# cluster-scoped — manage namespaces, CRDs, ClusterRoles/Bindings *including*
# bind+escalate (to install the controllers' own roles), admission webhooks and
# IngressClasses (the AWS LB Controller registers these); namespaced — full control
# only inside the enumerated platform install-target namespaces (argocd,
# nginx-gateway, monitoring, kube-system). It is NOT cluster-admin: it cannot touch
# workloads or secrets in any other namespace.
#
# Kubernetes escalation-prevention: creating a ClusterRole that itself holds
# bind/escalate requires a caller who already has those verbs — i.e. a
# cluster-admin. So the FIRST apply of this manifest must run as the gated
# cluster-bootstrap principal (or the human admin running the one-time bootstrap).
# After it exists, the tf-apply role (mapped to var.deployer_group) reconciles the
# cluster forever without ever being cluster-admin.
data "kubectl_file_documents" "ci_deployer" {
  content = templatefile("${var.manifest_path}", {
    deployer_group         = var.deployer_group
    provisioned_namespaces = var.provisioned_namespaces
    admin_namespaces       = distinct(concat(var.provisioned_namespaces, var.existing_admin_namespaces))
  })
}

resource "kubectl_manifest" "ci_deployer" {
  for_each  = data.kubectl_file_documents.ci_deployer.manifests
  yaml_body = each.value
  wait      = true
}
