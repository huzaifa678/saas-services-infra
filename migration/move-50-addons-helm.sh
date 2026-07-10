#!/usr/bin/env bash
# 50-addons-helm: helm releases + OTel collector k8s objects.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
LAYER=50-addons-helm
src_pull; layer_pull "$LAYER"

mv_one "$LAYER" 'module.root.module.k8s'                        'module.k8s'
mv_one "$LAYER" 'module.root.module.observability.module.otel'  'module.otel'

layer_push "$LAYER"
