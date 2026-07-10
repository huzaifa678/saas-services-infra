#!/usr/bin/env bash
# 30-edge: Verified Access (test/prod). The old AVA never applied cleanly
# (duplicate SG + invalid endpoint), so there is normally nothing to move --
# this is a fresh create. Import only if a partial instance exists.
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
echo "30-edge is a fresh create for ENV=$ENV. See MIGRATION.md for the optional AVA import."
