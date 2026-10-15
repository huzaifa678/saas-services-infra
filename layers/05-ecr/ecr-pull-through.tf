# ─── DRAFT: ECR pull-through cache for docker.elastic.co ─────────────────────
# Mirrors the Elastic images (elasticsearch, kibana) into ECR on first pull, so
# nodes pull over the ECR VPC endpoint instead of resolving + egressing to
# docker.elastic.co. On the live cluster the Kibana/Elasticsearch pulls failed
# while the VPC Route53 resolver was saturated (the CoreDNS/ndots storm) — a
# cache repo on the ECR path removes that dependency and the single upstream
# point of failure.
#
# Gated OFF by default (enable_elastic_pull_through_cache = false) so a plain
# apply is a no-op. The credential secret is NOT created here (no placeholder
# value in state) — it is seeded out-of-band by scripts/seed-secrets.sh, which
# creates "ecr-pullthroughcache/elastic" with {username, accessToken}. ECR
# requires a credential for a CUSTOM upstream even though docker.elastic.co
# serves anonymous pulls; the script defaults the fields to "anonymous" and only
# uses real Elastic creds if TF_VAR_elastic_registry_* are set.
#
# To enable:
#   1. ./scripts/seed-secrets.sh <env>          # seeds the secret (among others)
#   2. set enable_elastic_pull_through_cache = true, then `make apply ... LAYER=05-ecr`
#
# Still required before pulls actually flow through the cache:
#   - re-point the CD image refs at <account>.dkr.ecr.<region>.amazonaws.com/elastic/<path>
#   - grant the node role ecr:CreateRepository + ecr:BatchImportUpstreamImage
#     on arn:aws:ecr:<region>:<account>:repository/elastic/*  (modules/iam).

data "aws_secretsmanager_secret" "elastic_pull_through" {
  count = var.enable_elastic_pull_through_cache ? 1 : 0
  name  = "ecr-pullthroughcache/elastic"
}

resource "aws_ecr_pull_through_cache_rule" "elastic" {
  count                 = var.enable_elastic_pull_through_cache ? 1 : 0
  ecr_repository_prefix = "elastic"
  upstream_registry_url = "docker.elastic.co"
  credential_arn        = data.aws_secretsmanager_secret.elastic_pull_through[0].arn
}
