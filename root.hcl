locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.environment
  region      = local.env_vars.locals.region
  project     = local.env_vars.locals.project

  layer = basename(get_terragrunt_dir())

  state_bucket = "saas-state-bucket-399849"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
    Repo        = "saas-services-infra"
    DataClass   = local.environment == "prod" ? "confidential" : "internal"
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = local.state_bucket
    key          = "${local.environment}/${local.layer}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider_generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }
  EOF
}

# auth_provider / observability are only included when the env.hcl defines them.
# Platform env.hcl files do; the separate services env.hcl files (live/services/)
# do not, and their roots don't declare those variables.
inputs = merge(
  {
    project                     = local.project
    environment                 = local.environment
    region                      = local.region
    sizing                      = try(local.env_vars.locals.sizing, {})
    allowed_public_access_cidrs = try(local.env_vars.locals.allowed_public_access_cidrs, [])
  },
  try(local.env_vars.locals.auth_provider, null) != null ? { auth_provider = local.env_vars.locals.auth_provider } : {},
  try(local.env_vars.locals.observability, null) != null ? { observability = local.env_vars.locals.observability } : {},
)
