locals {
  common = data.terraform_remote_state.common.outputs
  db     = local.common.billing_db
}
