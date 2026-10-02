include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/bootstrap.hcl"
  merge_strategy = "deep"
  expose         = true
}

# prod: private-only endpoint fronted by Verified Access for humans; the in-VPC
# runner is the sole CI path to the API. The bootstrap Environment defaults to
# "prod" — protect it with required reviewers so the gated cluster-admin role can
# only be assumed through an approved deployment.
inputs = {
  runner_instance_type = "t3.medium"
}
