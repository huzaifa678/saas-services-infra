include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/bootstrap.hcl"
  merge_strategy = "deep"
  expose         = true
}

# ECR + OIDC roles only; no infra dependency. The account-wide GitHub OIDC
# provider is owned by dev's bootstrap, so this env does NOT create it — the ARN
# is auto-derived from the account id (no value to copy). Apply dev first.
inputs = {
  create_oidc_provider = false
}
