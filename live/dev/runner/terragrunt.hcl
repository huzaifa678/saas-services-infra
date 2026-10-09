include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/runner.hcl"
  merge_strategy = "deep"
  expose         = true
}

# Isolated CI runner VPC, peered to this env's app VPC for private EKS API reach.
inputs = {
  runner_instance_type = "t3.small"
}
