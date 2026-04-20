locals {
  common = data.terraform_remote_state.common.outputs
  db     = local.common.auth_db
}