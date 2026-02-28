#!/bin/bash
# run_capture_linux_compare.sh — Launch Flutter Linux compare UI and capture screenshot
#
# Captures a side-by-side view:
#   Syncfusion SfDataGrid (linux) vs VolvoxGrid SfDataGrid adapter (linux)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/flutter/example"
OUT_DIR="$ROOT_DIR/target/sfdatagrid/compare"
OUT_PNG="$OUT_DIR/linux_sfdatagrid_vs_volvoxgrid.png"
RUN_LOG="$OUT_DIR/linux_capture_run.log"

XVFB_SCREEN="${XVFB_SCREEN:-1920x1080x24}"
CAPTURE_DELAY="${CAPTURE_DELAY:-22}"

mkdir -p "$OUT_DIR"

echo "=== SfDataGrid Linux Capture: Syncfusion vs VolvoxGrid ==="
echo ""
command -v flutter >/dev/null 2>&1 || { echo "ERROR: flutter not found"; exit 1; }
command -v xvfb-run >/dev/null 2>&1 || { echo "ERROR: xvfb-run not found"; exit 1; }
command -v import >/dev/null 2>&1 || { echo "ERROR: import (ImageMagick) not found"; exit 1; }
command -v xwininfo >/dev/null 2>&1 || { echo "ERROR: xwininfo not found"; exit 1; }

echo "[1/4] Resolving example dependencies..."
(
  cd "$EXAMPLE_DIR"
  flutter pub get >/dev/null
)
echo "  Done."

echo "[2/4] Launching Linux compare window under Xvfb..."
xvfb-run -a -s "-screen 0 ${XVFB_SCREEN}" bash -lc "
set -euo pipefail
cd '$EXAMPLE_DIR'
flutter run -d linux -t lib/compare_sfdatagrid_linux.dart > '$RUN_LOG' 2>&1 &
APP_PID=\$!
cleanup() {
  kill \$APP_PID >/dev/null 2>&1 || true
  wait \$APP_PID >/dev/null 2>&1 || true
}
trap cleanup EXIT
READY=0
for _ in \$(seq 1 '$CAPTURE_DELAY'); do
  if ! kill -0 \$APP_PID >/dev/null 2>&1; then
    echo 'ERROR: Flutter app terminated before capture.'
    tail -n 120 '$RUN_LOG' || true
    exit 1
  fi
  if grep -q 'A Dart VM Service on Linux is available' '$RUN_LOG'; then
    READY=1
    break
  fi
  sleep 1
done
if [ \"\$READY\" -eq 0 ]; then
  echo 'WARNING: VM service readiness not detected before timeout; attempting capture anyway.'
fi
sleep 2
WIN_ID=\$(xwininfo -root -tree | awk '/SfDataGrid Linux Compare|volvoxgrid_example/ {print \$1; exit}')
if [ -n \"\$WIN_ID\" ]; then
  import -window \"\$WIN_ID\" '$OUT_PNG'
else
  import -window root '$OUT_PNG'
fi
"
echo "  Done."

echo "[3/4] Verifying output..."
if [ ! -f "$OUT_PNG" ]; then
  echo "ERROR: capture file not found: $OUT_PNG"
  exit 1
fi
ls -lh "$OUT_PNG"

echo "[4/4] Complete."
echo "  Capture: $OUT_PNG"
echo "  Run log: $RUN_LOG"
