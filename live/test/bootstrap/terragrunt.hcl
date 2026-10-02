include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/bootstrap.hcl"
  merge_strategy = "deep"
  expose         = true
}

# test: private endpoint — the in-VPC runner is the CI path to the API.
inputs = {
  runner_instance_type = "t3.medium"
}
