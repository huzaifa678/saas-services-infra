terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC — keyless AWS auth for the self-hosted runner. Even though
# the runner is a standing EC2 host, its *instance profile* holds no deploy
# rights (see modules/gha-runner). Each job federates a short-lived OIDC token
# into one of the scoped roles below, so a compromised runner host still cannot
# deploy or reach the cluster. No long-lived access keys are stored anywhere.
# ---------------------------------------------------------------------------

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# Fetch GitHub's OIDC TLS cert so the thumbprint is never hardcoded or stale.
data "tls_certificate" "github" {
  count = var.create_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [for c in data.tls_certificate.github[0].certificates : c.sha1_fingerprint]
  tags            = var.tags
}

locals {
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.oidc_provider_arn
  repo         = "${var.github_owner}/${var.github_repo}"

  # Which GitHub ref/context each role accepts (the OIDC `sub` claim):
  #   * apply: the default branch (push) OR the per-env GitHub Environments.
  #   * plan : pull-request runs, plus the default branch (manual plan dispatch).
  apply_subjects = concat(
    ["repo:${local.repo}:ref:refs/heads/${var.default_branch}"],
    [for e in var.apply_environments : "repo:${local.repo}:environment:${e}"],
  )
  pr_subjects = [
    "repo:${local.repo}:pull_request",
    "repo:${local.repo}:ref:refs/heads/${var.default_branch}",
  ]
}

# Reusable trust: Web Identity from the GitHub provider, locked to the
# sts.amazonaws.com audience and the given `sub` subjects.
data "aws_iam_policy_document" "assume_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.apply_subjects
    }
  }
}

data "aws_iam_policy_document" "assume_pr" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.pr_subjects
    }
  }
}

# State-backend access shared by plan (read+lock) and apply.
data "aws_iam_policy_document" "tf_state" {
  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}"]
  }
  statement {
    sid    = "StateObjectRW"
    effect = "Allow"
    # GetObject/PutObject/DeleteObject cover read, write and the S3-native
    # lockfile (use_lockfile) the Terragrunt backend uses.
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket}/${var.environment}/*"]
  }
}

# ── Role 1: tf-plan (PRs). Read-only + state, so a fork/PR plan can refresh and
# diff but never mutate infrastructure. ──────────────────────────────────────
resource "aws_iam_role" "tf_plan" {
  name               = "${var.name}-gha-tf-plan"
  assume_role_policy = data.aws_iam_policy_document.assume_pr.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "tf_plan_readonly" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "tf_plan_state" {
  name   = "${var.name}-gha-tf-plan-state"
  role   = aws_iam_role.tf_plan.id
  policy = data.aws_iam_policy_document.tf_state.json
}

# ── Role 2: tf-apply (main / per-env Environments). The steady-state deployer.
# Cluster-side it is only the least-privilege `ci-deployers` K8s group (mapped by
# the bootstrap layer's access entry), never a cluster-admin. ─────────────────
resource "aws_iam_role" "tf_apply" {
  name               = "${var.name}-gha-tf-apply"
  assume_role_policy = data.aws_iam_policy_document.assume_apply.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "tf_apply" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${var.apply_managed_policy}"
}

resource "aws_iam_role_policy" "tf_apply_state" {
  name   = "${var.name}-gha-tf-apply-state"
  role   = aws_iam_role.tf_apply.id
  policy = data.aws_iam_policy_document.tf_state.json
}

# ── Role 3: cluster-bootstrap (one-time, break-glass). Trust is locked with
# StringEquals to the PROTECTED bootstrap Environment ONLY — no branch-push
# subject — so it is assumable solely through an approved, reviewed deployment.
# It is the sole principal the bootstrap layer grants a cluster-admin access
# entry, so it (and only it) can create the escalation-capable ci-deployer RBAC.
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "assume_bootstrap" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:environment:${var.bootstrap_environment}"]
    }
  }
}

resource "aws_iam_role" "cluster_bootstrap" {
  name               = "${var.name}-gha-cluster-bootstrap"
  assume_role_policy = data.aws_iam_policy_document.assume_bootstrap.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_bootstrap" {
  role       = aws_iam_role.cluster_bootstrap.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${var.apply_managed_policy}"
}
