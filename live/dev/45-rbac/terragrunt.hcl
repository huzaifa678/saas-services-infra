include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/45-rbac.hcl"
  merge_strategy = "deep"
  expose         = true
}

# Cluster RBAC + EKS access entries. Applied by the gated cluster-bootstrap role
# because the ci-deployer RBAC needs cluster-admin on first apply — that role is
# granted admin at platform time (10-platform cluster_admin_principal_arns), so the
# cluster-bootstrap workflow can first-apply the full layer (scope: full-layer) and
# re-apply -target=module.ci_deployer_rbac (scope: rbac-only) for recovery.
inputs = {}
