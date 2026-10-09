include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/bootstrap.hcl"
  merge_strategy = "deep"
  expose         = true
}

# ECR + OIDC provider/roles only; no infra dependency, applied first.
# dev OWNS the single account-wide GitHub OIDC provider (there can be only one per
# account). Apply dev's bootstrap before test/prod's, which reference it.
inputs = {
  create_oidc_provider = true
}
