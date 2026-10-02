include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/bootstrap.hcl"
  merge_strategy = "deep"
  expose         = true
}

# dev: public-endpoint cluster, so the runner is optional. The RBAC split + OIDC
# roles still apply so dev mirrors test/prod. Keep the runner small.
inputs = {
  runner_instance_type = "t3.small"
}
