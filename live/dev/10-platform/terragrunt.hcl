include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/10-platform.hcl"
  merge_strategy = "deep"
  expose         = true
}

inputs = {
  kubernetes_version = "1.34"
}
