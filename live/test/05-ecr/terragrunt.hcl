include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/05-ecr.hcl"
  merge_strategy = "deep"
  expose         = true
}

# Single ECR registry for every microservice image in this env.
inputs = {}
