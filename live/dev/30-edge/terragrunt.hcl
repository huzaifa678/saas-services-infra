include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/30-edge.hcl"
  merge_strategy = "deep"
  expose         = true
}

# Verified Access is disabled in dev (public endpoint), so no AVA inputs.
inputs = {}
