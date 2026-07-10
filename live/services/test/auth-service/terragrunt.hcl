include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/services/_envcommon/auth-service.hcl"
  merge_strategy = "deep"
  expose         = true
}
