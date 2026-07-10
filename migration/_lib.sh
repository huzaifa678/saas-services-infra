#!/usr/bin/env bash
set -euo pipefail

: "${ENV:?set ENV=dev|test|prod}"
: "${STATE_BUCKET:=saas-state-bucket-399849}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/migration/.work/$ENV"
mkdir -p "$WORK"

SRC_STATE="$WORK/_src.tfstate"

src_pull() {
  terraform -chdir="$ROOT/migration/_src" init -reconfigure -input=false \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="key=$ENV/terraform.tfstate" \
    -backend-config="region=us-east-1" >/dev/null
  terraform -chdir="$ROOT/migration/_src" state pull > "$SRC_STATE"
  echo "pulled combined state -> $SRC_STATE"
}

# layer_pull <layer>  -> init the layer's live unit through Terragrunt (which
# generates the backend at the correct <env>/<layer> key) and pull its state.
# The layer modules no longer carry a backend block, so Terragrunt owns it.
layer_pull() {
  local layer="$1"
  terragrunt init --working-dir "$ROOT/live/$ENV/$layer" --non-interactive >/dev/null
  terragrunt state pull --working-dir "$ROOT/live/$ENV/$layer" > "$WORK/$layer.tfstate"
}

# mv_one <layer> <src-address> <dst-address>
# No-op (with a warning) if the source address is absent, so the scripts are
# idempotent and tolerate count/for_each variants that differ per environment.
mv_one() {
  local layer="$1" src="$2" dst="$3"
  if ! terraform state list -state="$SRC_STATE" | grep -qxF "$src"; then
    echo "  skip (absent): $src"
    return 0
  fi
  terraform state mv \
    -state="$SRC_STATE" \
    -state-out="$WORK/$layer.tfstate" \
    "$src" "$dst"
  echo "  moved: $src -> $dst"
}

# layer_push <layer> — push the rebuilt layer state (via Terragrunt) and the
# shrunken combined src state (plain terraform, it still has a backend block).
layer_push() {
  local layer="$1"
  terragrunt state push --working-dir "$ROOT/live/$ENV/$layer" "$WORK/$layer.tfstate"
  terraform -chdir="$ROOT/migration/_src" state push "$SRC_STATE"
  echo "pushed $layer state and updated combined state"
}
