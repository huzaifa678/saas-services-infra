include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/30-edge.hcl"
  merge_strategy = "deep"
  expose         = true
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

inputs = {
  ava_custom_subdomain = local.env.ava.custom_subdomain
  ava_oidc_issuer      = local.env.ava.oidc_issuer

  # Authenticating a user and then permitting everyone is not zero trust. The
  # module rejects an unconditional `when { true }` permit.
  ava_policy_document = <<-CEDAR
    permit(principal, action, resource)
    when {
      context.oidc.email_verified == true &&
      context.oidc.groups.contains("platform-admins")
    };
  CEDAR
}
