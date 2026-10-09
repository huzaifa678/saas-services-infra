terraform {
  source = "${get_repo_root()}//layers/bootstrap"
}

# bootstrap has NO infra dependency: it is the account/CI identity substrate
# (ECR toolchain repo + GitHub OIDC provider + scoped roles) and owns its own
# CMK. It can be applied FIRST, before 00-network. The self-hosted runner and
# its VPC live in the separate `runner` layer; the cluster wiring (EKS access
# entries + ci-deployer RBAC) lives in `45-rbac`.
