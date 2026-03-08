#!/usr/bin/env bash
set -euo pipefail

# Unified build dispatcher — runs inside Docker (Dockerfile.all).
#
# Reads BUILD_TARGET env var to select what to build.
# Values: android, desktop, ios, wasm, web, all (default: all)
#
# Usage (inside Docker):
#   BUILD_TARGET=all    /opt/volvoxgrid/build_all.sh
#   BUILD_TARGET=android /opt/volvoxgrid/build_all.sh

BUILD_TARGET="${BUILD_TARGET:-all}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(pwd)}"

run_android() {
  echo "========================================"
  echo "  Building: Android AAR"
  echo "========================================"
  local full_group_id="${GROUP_ID:-io.github.ivere27}"
  local full_artifact_id="${ARTIFACT_ID:-volvoxgrid-android}"
  local include_lite="${BUILD_ANDROID_INCLUDE_LITE:-0}"
  local lite_group_id="${AAR_LITE_GROUP_ID:-${full_group_id}}"
  local lite_artifact_id="${AAR_LITE_ARTIFACT_ID:-volvoxgrid-android-lite}"

  GROUP_ID="${full_group_id}" \
  ARTIFACT_ID="${full_artifact_id}" \
  PLUGIN_BUILD_MODE=full \
    "${SCRIPT_DIR}/build_android_aar.sh"

  case "${include_lite}" in
    1|true|TRUE|yes|YES|on|ON)
      echo "----------------------------------------"
      echo "  Building: Android AAR (lite)"
      echo "----------------------------------------"
      GROUP_ID="${lite_group_id}" \
      ARTIFACT_ID="${lite_artifact_id}" \
      PLUGIN_BUILD_MODE=lite \
        "${SCRIPT_DIR}/build_android_aar.sh"
      ;;
  esac
}

run_desktop() {
  echo "========================================"
  echo "  Building: Desktop JAR"
  echo "========================================"
  local desktop_group_id="${DESKTOP_GROUP_ID:-io.github.ivere27}"
  local desktop_artifact_id="${DESKTOP_ARTIFACT_ID:-volvoxgrid-desktop}"
  local desktop_version="${DESKTOP_VERSION:-${VERSION:-0.2.0}}"
  local desktop_git_commit="${DESKTOP_GIT_COMMIT:-${GIT_COMMIT:-unknown}}"
  local desktop_build_date="${DESKTOP_BUILD_DATE:-${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}}"

  GROUP_ID="${desktop_group_id}" \
  ARTIFACT_ID="${desktop_artifact_id}" \
  VERSION="${desktop_version}" \
  GIT_COMMIT="${desktop_git_commit}" \
  BUILD_DATE="${desktop_build_date}" \
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
  echo "  Building: WASM + Web demos/bundles"
  echo "========================================"
  local dist_dir="${DIST_DIR:-${REPO_ROOT}/dist/wasm}"
  local dist_lite_dir="${DIST_LITE_DIR:-${REPO_ROOT}/dist/wasm-lite}"
  local web_target="${WEB_DOCKER_TARGET:-all}"
  WEB_DIST_DIR="${WEB_DIST_DIR:-${REPO_ROOT}/dist/web}"
  WEB_BUNDLE_VERSION="${WEB_BUNDLE_VERSION:-${VERSION:-0.2.0}}"
  if [[ -z "${WEB_DOCKER_TARGET:-}" && "${BUILD_TARGET}" == "wasm" ]]; then
    web_target="bundle"
  fi

  VOLVOXGRID_VERSION="${WEB_BUNDLE_VERSION}" \
  WEB_DOCKER_TARGET="${web_target}" \
  WEB_SCALE="${WEB_SCALE:-1.0}" \
    bash "${REPO_ROOT}/docker/build_web.sh"

  echo "WASM artifacts: ${dist_dir}/"
  echo "WASM lite artifacts: ${dist_lite_dir}/"
  echo "Web demos:"
  echo "  ${WEB_DIST_DIR}/demos/web"
  echo "  ${WEB_DIST_DIR}/demos/sheet"
  echo "  ${WEB_DIST_DIR}/demos/sheet-lite"
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
  web)
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
    echo "Valid values: android, desktop, ios, wasm, web, all" >&2
    exit 1
    ;;
esac
