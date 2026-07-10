include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/40-observability.hcl"
  merge_strategy = "deep"
  expose         = true
}

inputs = {}
