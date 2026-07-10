#!/usr/bin/env bash
# 40-observability: managed Grafana/Prometheus, OpenSearch, collector IAM.
# The otel sub-module stays behind and moves to 50-addons-helm.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
LAYER=40-observability
src_pull; layer_pull "$LAYER"

mv_one "$LAYER" 'module.root.module.observability.module.grafana[0]' 'module.observability.module.grafana[0]'
mv_one "$LAYER" 'module.root.module.observability.module.elk[0]'     'module.observability.module.elk[0]'

layer_push "$LAYER"
