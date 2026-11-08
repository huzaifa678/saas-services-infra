include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/20-data.hcl"
  merge_strategy = "deep"
  expose         = true
}

inputs = {
  # Create the ElastiCache RBAC user group ("saas-redis") + disabled `default`
  # user that the platform AppCache composition adopts. WARNING: turning this on
  # also disables the shared Redis AUTH token (auth_token_enabled flips to false
  # in layers/20-data), so any consumer still authenticating with that token must
  # migrate to RBAC users.
  redis_rbac_enabled = true
}
