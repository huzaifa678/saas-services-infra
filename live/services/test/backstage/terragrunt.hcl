include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/services/_envcommon/backstage.hcl"
  merge_strategy = "deep"
  expose         = true
}

inputs = {
  # KEYCLOAK_CLIENT_SECRET and ARGOCD_AUTH_TOKEN are generated in-cluster by the
  # CD backstage chart (secretGeneration.enabled), so they are not seeded into
  # saas/backstage-input and must be omitted from the backstage-app secret here.
  generate_secrets_in_cluster = true
}
