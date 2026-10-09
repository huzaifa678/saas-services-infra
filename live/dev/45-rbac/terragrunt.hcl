include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/45-rbac.hcl"
  merge_strategy = "deep"
  expose         = true
}

# Cluster RBAC + EKS access entries. Applied by the gated cluster-bootstrap role
# (or the human bootstrapper) because the ci-deployer RBAC needs cluster-admin on
# first apply. The cluster-bootstrap workflow re-applies -target=module.ci_deployer_rbac.
inputs = {}
