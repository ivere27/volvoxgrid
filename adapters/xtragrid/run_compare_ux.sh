#!/bin/bash
# run_compare_ux.sh — UX-style compare entrypoint with a longer settle window.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_SETTLE_MS="${VOLVOXGRID_XTRAGRID_UX_SETTLE_MS:-700}"
exec "$SCRIPT_DIR/run_compare_ui.sh" --settle-ms "$DEFAULT_SETTLE_MS" "$@"
