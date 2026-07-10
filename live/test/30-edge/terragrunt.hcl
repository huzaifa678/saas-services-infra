include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "${get_repo_root()}/live/_envcommon/30-edge.hcl"
  merge_strategy = "deep"
  expose         = true
}

# Supply ava_oidc_client_secret via TF_VAR_ava_oidc_client_secret, never in VCS.
inputs = {
  ava_custom_subdomain = "eks-test.example.internal"
  ava_oidc_issuer      = "https://example.eu.auth0.com"
  ava_oidc_client_id   = "REPLACE_ME"

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
