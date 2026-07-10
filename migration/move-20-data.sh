#!/usr/bin/env bash
# 20-data: RDS xN, ElastiCache, MSK, data-tier SGs.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
LAYER=20-data
src_pull; layer_pull "$LAYER"

mv_one "$LAYER" 'module.root.module.rds_subscription'  'module.rds["subscription"]'
mv_one "$LAYER" 'module.root.module.rds_billing'       'module.rds["billing"]'
mv_one "$LAYER" 'module.root.module.rds_usage'         'module.rds["usage"]'
mv_one "$LAYER" 'module.root.module.rds_auth[0]'       'module.rds["auth"]'       # test only
mv_one "$LAYER" 'module.root.module.rds_keycloak[0]'   'module.rds["keycloak"]'   # dev/prod
mv_one "$LAYER" 'module.root.module.elasticache'       'module.elasticache'
mv_one "$LAYER" 'module.root.module.msk'               'module.msk'
# Data-tier SG shells move; ingress rules re-create under the keyed for_each.
mv_one "$LAYER" 'module.root.module.security_group.aws_security_group.rds_sg'        'module.data_security_groups.aws_security_group.this["rds"]'
mv_one "$LAYER" 'module.root.module.security_group.aws_security_group.redis_sg'      'module.data_security_groups.aws_security_group.this["redis"]'
mv_one "$LAYER" 'module.root.module.security_group.aws_security_group.msk_sg'        'module.data_security_groups.aws_security_group.this["msk"]'
mv_one "$LAYER" 'module.root.module.security_group.aws_security_group.opensearch_sg' 'module.data_security_groups.aws_security_group.this["opensearch"]'

layer_push "$LAYER"
echo "NOTE: MSK auth flips off 'unauthenticated' -> SASL; ElastiCache gains an AUTH token. Client-visible."
