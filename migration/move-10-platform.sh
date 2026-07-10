#!/usr/bin/env bash
# 10-platform: EKS, IAM, node SG, pod identity.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
LAYER=10-platform
src_pull; layer_pull "$LAYER"

mv_one "$LAYER" 'module.root.module.eks'                                  'module.eks'
mv_one "$LAYER" 'module.root.module.iam'                                  'module.iam'
mv_one "$LAYER" 'module.root.aws_eks_access_entry.karpenter_node'         'aws_eks_access_entry.karpenter_node'
for k in cert_manager external_dns external_secrets aws_lb_controller karpenter ebs_csi_controller; do
  mv_one "$LAYER" "module.root.aws_eks_pod_identity_association.this[\"$k\"]" "aws_eks_pod_identity_association.this[\"$k\"]"
done
# Preserve the node SG (and its karpenter discovery tag / id). Its rules re-create.
mv_one "$LAYER" 'module.root.module.security_group.aws_security_group.eks_nodes' \
                'module.node_security_group.aws_security_group.eks_nodes'

layer_push "$LAYER"
echo "NOTE: node SG rules re-create as aws_vpc_security_group_*_rule (stateless L4, non-disruptive)."
