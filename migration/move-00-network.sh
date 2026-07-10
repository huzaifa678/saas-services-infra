#!/usr/bin/env bash
# 00-network: VPC, KMS, flow logs, ECR, Glue registry.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
LAYER=00-network
src_pull; layer_pull "$LAYER"

mv_one "$LAYER" 'module.root.module.vpc'                                  'module.vpc'
mv_one "$LAYER" 'module.root.aws_kms_key.main'                           'aws_kms_key.main'
mv_one "$LAYER" 'module.root.aws_kms_alias.main'                         'aws_kms_alias.main'
mv_one "$LAYER" 'module.root.aws_cloudwatch_log_group.vpc_flow_logs'     'aws_cloudwatch_log_group.vpc_flow_logs'
mv_one "$LAYER" 'module.root.aws_iam_role.vpc_flow_log'                  'aws_iam_role.vpc_flow_log'
mv_one "$LAYER" 'module.root.aws_iam_role_policy.vpc_flow_log'           'aws_iam_role_policy.vpc_flow_log'
mv_one "$LAYER" 'module.root.aws_glue_registry.schema_registry'         'aws_glue_registry.schema_registry'
for svc in api-gateway auth-service subscription-service billing-service usage-service; do
  mv_one "$LAYER" "module.root.aws_ecr_repository.services[\"$svc\"]"    "aws_ecr_repository.services[\"$svc\"]"
done

layer_push "$LAYER"
echo "NOTE: aws_kms_key_policy.main is a NEW resource; it will show as an add on plan."
