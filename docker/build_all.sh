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
  local desktop_version="${DESKTOP_VERSION:-${VERSION:-0.1.2}}"
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
  echo "  Building: WASM + Web JS bundles"
  echo "========================================"
  DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/wasm}"
  DIST_LITE_DIR="${DIST_LITE_DIR:-${REPO_ROOT}/dist/wasm-lite}"
  WEB_DIST_DIR="${WEB_DIST_DIR:-${REPO_ROOT}/dist/web}"
  WEB_BUNDLE_VERSION="${WEB_BUNDLE_VERSION:-${VERSION:-0.1.2}}"
  WEB_BUNDLE_NAME="${WEB_BUNDLE_NAME:-volvoxgrid-web-${WEB_BUNDLE_VERSION}.zip}"
  WEB_BUNDLE_LITE_NAME="${WEB_BUNDLE_LITE_NAME:-volvoxgrid-web-lite-${WEB_BUNDLE_VERSION}.zip}"

  package_web_bundle() {
    local root_name="$1"
    local wasm_dir="$2"
    local zip_path="$3"
    local bundle_tmp
    bundle_tmp="$(mktemp -d /tmp/volvoxgrid-web-XXXXXX)"
    local bundle_root="${bundle_tmp}/${root_name}"

    mkdir -p "${bundle_root}/js" "${bundle_root}/wasm"
    cp -a "${REPO_ROOT}/web/js/dist/." "${bundle_root}/js/"
    cp "${REPO_ROOT}/web/js/package.json" "${bundle_root}/js/"
    cp -a "${wasm_dir}/." "${bundle_root}/wasm/"

    (
      cd "${bundle_tmp}"
      rm -f "${zip_path}"
      zip -qr "${zip_path}" "${root_name}"
    )
    rm -rf "${bundle_tmp}"
  }

  mkdir -p "${DIST_DIR}" "${DIST_LITE_DIR}" "${WEB_DIST_DIR}"
  (
    cd "${REPO_ROOT}/web/crate"
    rustup run nightly wasm-pack build . --release --target web --out-dir "${DIST_DIR}" --features gpu
    rustup run nightly wasm-pack build . --release --target web --out-dir "${DIST_LITE_DIR}" --no-default-features
  )

  (
    cd "${REPO_ROOT}/web/js"
    npm ci
    npm run build
  )

  package_web_bundle "volvoxgrid-web" "${DIST_DIR}" "${WEB_DIST_DIR}/${WEB_BUNDLE_NAME}"
  package_web_bundle "volvoxgrid-web-lite" "${DIST_LITE_DIR}" "${WEB_DIST_DIR}/${WEB_BUNDLE_LITE_NAME}"

  echo "WASM artifacts: ${DIST_DIR}/"
  echo "WASM lite artifacts: ${DIST_LITE_DIR}/"
  echo "Web bundles:"
  echo "  ${WEB_DIST_DIR}/${WEB_BUNDLE_NAME}"
  echo "  ${WEB_DIST_DIR}/${WEB_BUNDLE_LITE_NAME}"
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
