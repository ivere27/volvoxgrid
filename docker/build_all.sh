#!/usr/bin/env bash
set -euo pipefail

# Unified build dispatcher — runs inside Docker (Dockerfile.all).
#
# Reads BUILD_TARGET env var to select what to build.
# Values: android, desktop, ios, wasm, all (default: all)
#
# Usage (inside Docker):
#   BUILD_TARGET=all    /opt/volvoxgrid/build_all.sh
#   BUILD_TARGET=android /opt/volvoxgrid/build_all.sh

BUILD_TARGET="${BUILD_TARGET:-all}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

run_android() {
  echo "========================================"
  echo "  Building: Android AAR"
  echo "========================================"
  "${SCRIPT_DIR}/build_android_aar.sh"
}

run_desktop() {
  echo "========================================"
  echo "  Building: Desktop JAR"
  echo "========================================"
  "${SCRIPT_DIR}/build_desktop_jar.sh"
}

run_ios() {
  echo "========================================"
  echo "  Building: iOS XCFramework"
  echo "========================================"
  "${SCRIPT_DIR}/build_ios.sh"
}

run_wasm() {
  echo "========================================"
  echo "  Building: WASM package"
  echo "========================================"
  REPO_ROOT="${REPO_ROOT:-$(pwd)}"
  DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/wasm}"
  mkdir -p "${DIST_DIR}"
  (
    cd "${REPO_ROOT}/web/crate"
    rustup run nightly wasm-pack build . --release --target web --out-dir "${DIST_DIR}" --features gpu
  )
  echo "WASM artifacts: ${DIST_DIR}/"
}

case "${BUILD_TARGET}" in
  android)
    run_android
    ;;
  desktop)
    run_desktop
    ;;
  ios)
    run_ios
    ;;
  wasm)
    run_wasm
    ;;
  all)
    run_android
    echo ""
    run_desktop
    echo ""
    run_ios
    echo ""
    run_wasm
    echo ""
    echo "========================================"
    echo "  All builds complete."
    echo "========================================"
    ;;
  *)
    echo "Error: unknown BUILD_TARGET '${BUILD_TARGET}'." >&2
    echo "Valid values: android, desktop, ios, wasm, all" >&2
    exit 1
    ;;
esac
