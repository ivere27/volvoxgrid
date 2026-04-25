#!/usr/bin/env bash
set -euo pipefail

# Web build dispatcher for Dockerfile.web.
# Produces non-server dist artifacts and web bundles.

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
TARGET="${WEB_DOCKER_TARGET:-all}"
VERSION="${VOLVOXGRID_VERSION:-${VERSION:-0.8.0}}"
WASM_DIST_ROOT="${REPO_ROOT}/dist/wasm"
WASM_LITE_DIST_ROOT="${REPO_ROOT}/dist/wasm-lite"
WEB_DIST_ROOT="${REPO_ROOT}/dist/web"
CDN_BASE="https://cdn.jsdelivr.net/npm"
WASM_CDN_URL="${CDN_BASE}/volvoxgrid@${VERSION}/wasm/volvoxgrid_wasm.js"
WASM_LITE_CDN_URL="${CDN_BASE}/volvoxgrid-lite@${VERSION}/wasm/volvoxgrid_wasm.js"
TMP_ROOT="$(mktemp -d /tmp/volvoxgrid-web-build-XXXXXX)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

ensure_dir() {
  mkdir -p "$1"
}

copy_dir_clean() {
  local src="$1"
  local dst="$2"
  rm -rf "${dst}"
  mkdir -p "${dst}"
  cp -a "${src}/." "${dst}/"
}

snapshot_current_wasm() {
  local dst="$1"
  copy_dir_clean "${REPO_ROOT}/web/example/wasm" "${dst}"
}

build_js() {
  (
    cd "${REPO_ROOT}/web/js"
    npm install
    npm run build
  )
}

write_sheet_demo_index() {
  local out_dir="$1"
  local title="$2"
  local cdn_base="${3:-}"  # e.g. "https://cdn.jsdelivr.net/npm"
  local wasm_pkg="${4:-volvoxgrid}"  # "volvoxgrid" or "volvoxgrid-lite"

  local css_url="./assets/sheet.css"
  local importmap_vg="./volvoxgrid/index.js"
  local wasm_url="./wasm/volvoxgrid_wasm.js"
  local sheet_url="./volvox-sheet.js"

  if [[ -n "${cdn_base}" ]]; then
    css_url="${cdn_base}/@volvoxgrid/sheet@${VERSION}/dist/assets/sheet.css"
    importmap_vg="${cdn_base}/volvoxgrid@${VERSION}/dist/index.js"
    wasm_url="${cdn_base}/${wasm_pkg}@${VERSION}/wasm/volvoxgrid_wasm.js"
    sheet_url="${cdn_base}/@volvoxgrid/sheet@${VERSION}/dist/volvox-sheet.js"
  fi

  cat > "${out_dir}/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title}</title>
  <link rel="stylesheet" href="${css_url}" />
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; }
    #app { width: 100%; height: 100%; }
  </style>
  <script type="importmap">
  {
    "imports": {
      "volvoxgrid": "${importmap_vg}"
    }
  }
  </script>
</head>
<body>
  <div id="app"></div>
  <script type="module">
    import init from "${wasm_url}";
    import * as wasm from "${wasm_url}";
    import { VolvoxSheet } from "${sheet_url}";

    async function main() {
      await init();
      if (typeof wasm.init_v1_plugin === "function") {
        wasm.init_v1_plugin();
      }

      const sheet = new VolvoxSheet({
        container: document.getElementById("app"),
        wasm,
        rows: 100,
        cols: 26,
        data: [
          ["Name", "Age", "City", "Department", "Salary"],
          ["Alice", "30", "New York", "Engineering", "95000"],
          ["Bob", "25", "London", "Marketing", "72000"],
          ["Charlie", "35", "Tokyo", "Engineering", "105000"],
          ["Diana", "28", "Berlin", "Design", "85000"],
          ["Eve", "32", "Paris", "Marketing", "78000"]
        ]
      });

      window.sheet = sheet;
    }

    main().catch(console.error);
  </script>
</body>
</html>
EOF
}

package_bundle() {
  local root_name="$1"
  local wasm_src="$2"
  local zip_path="$3"
  local bundle_tmp="${TMP_ROOT}/${root_name}"
  local bundle_root="${bundle_tmp}/${root_name}"

  rm -rf "${bundle_tmp}"
  mkdir -p "${bundle_root}/js" "${bundle_root}/wasm"
  cp -a "${REPO_ROOT}/web/js/dist/." "${bundle_root}/js/"
  cp "${REPO_ROOT}/web/js/package.json" "${bundle_root}/js/"
  cp -a "${wasm_src}/." "${bundle_root}/wasm/"
  ensure_dir "$(dirname "${zip_path}")"
  (
    cd "${bundle_tmp}"
    rm -f "${zip_path}"
    zip -qr "${zip_path}" "${root_name}"
  )
}

build_bundles() {
  local wasm_gpu="${TMP_ROOT}/wasm-gpu"
  local wasm_lite="${TMP_ROOT}/wasm-lite"
  local zip_gpu="${WEB_DIST_ROOT}/volvoxgrid-web-${VERSION}.zip"
  local zip_lite="${WEB_DIST_ROOT}/volvoxgrid-web-lite-${VERSION}.zip"

  make wasm
  snapshot_current_wasm "${wasm_gpu}"
  copy_dir_clean "${wasm_gpu}" "${WASM_DIST_ROOT}"
  make wasm-lite
  snapshot_current_wasm "${wasm_lite}"
  copy_dir_clean "${wasm_lite}" "${WASM_LITE_DIST_ROOT}"
  build_js

  package_bundle "volvoxgrid-web" "${wasm_gpu}" "${zip_gpu}"
  package_bundle "volvoxgrid-web-lite" "${wasm_lite}" "${zip_lite}"

  echo "Exported WASM dist:"
  echo "  ${WASM_DIST_ROOT}"
  echo "  ${WASM_LITE_DIST_ROOT}"
  echo "Built web bundles:"
  echo "  ${zip_gpu}"
  echo "  ${zip_lite}"
}

build_web_dist() {
  make wasm
  (
    cd "${REPO_ROOT}/web/example"
    npm ci
    VITE_WASM_URL="${WASM_CDN_URL}" VITE_VG_INITIAL_SCALE="${WEB_SCALE:-1.0}" npm run build -- --base /demos/web/
  )
  copy_dir_clean "${REPO_ROOT}/web/example/dist" "${WEB_DIST_ROOT}/demos/web"
  copy_dir_clean "${REPO_ROOT}/web/example/wasm" "${WEB_DIST_ROOT}/demos/web/wasm"
  if [[ -d "${REPO_ROOT}/web/example/public/doom" ]]; then
    copy_dir_clean "${REPO_ROOT}/web/example/public/doom" "${WEB_DIST_ROOT}/demos/web/doom"
  fi
  echo "Built web dist: ${WEB_DIST_ROOT}/demos/web"
}

build_sheet_dist() {
  local mode="${1:-gpu}" # gpu|lite
  local out_dir="${WEB_DIST_ROOT}/demos/sheet"
  local wasm_pkg="volvoxgrid"
  if [[ "${mode}" == "lite" ]]; then
    out_dir="${WEB_DIST_ROOT}/demos/sheet-lite"
    wasm_pkg="volvoxgrid-lite"
    make wasm-lite
  else
    make wasm
  fi

  build_js
  mkdir -p "${REPO_ROOT}/adapters/sheet/wasm"
  ln -sf "${REPO_ROOT}/web/example/wasm/"* "${REPO_ROOT}/adapters/sheet/wasm/"
  (
    cd "${REPO_ROOT}/adapters/sheet"
    npm install
    npm run build
  )
  # Only index.html goes to Firebase; all other assets served from CDN
  mkdir -p "${out_dir}"
  if [[ "${mode}" == "lite" ]]; then
    write_sheet_demo_index "${out_dir}" "VolvoxSheet Lite" "${CDN_BASE}" "${wasm_pkg}"
  else
    write_sheet_demo_index "${out_dir}" "VolvoxSheet" "${CDN_BASE}" "${wasm_pkg}"
  fi
  echo "Built sheet dist: ${out_dir}"
}

build_report_dist() {
  make wasm
  mkdir -p "${REPO_ROOT}/adapters/report/wasm"
  ln -sf "${REPO_ROOT}/web/example/wasm/"* "${REPO_ROOT}/adapters/report/wasm/"
  (
    cd "${REPO_ROOT}/adapters/report"
    npm install
    npm run build -- --base /demos/report/
  )
  copy_dir_clean "${REPO_ROOT}/adapters/report/dist" "${WEB_DIST_ROOT}/demos/report"
  copy_dir_clean "${REPO_ROOT}/web/example/wasm" "${WEB_DIST_ROOT}/demos/report/wasm"
  echo "Built report dist: ${WEB_DIST_ROOT}/demos/report"
}

case "${TARGET}" in
  all|bundle|web|sheet|sheet-lite|report|wasm|wasm-lite|wasm-threaded)
    ;;
  *)
    echo "Error: unsupported WEB_DOCKER_TARGET='${TARGET}'." >&2
    echo "Valid values: all, bundle, web, sheet, sheet-lite, report, wasm, wasm-lite, wasm-threaded" >&2
    exit 1
    ;;
esac

echo "========================================"
echo "  Docker Web Build"
echo "========================================"
echo "Target: ${TARGET}"
echo "Version: ${VERSION}"
echo "Output: ${WEB_DIST_ROOT}"

cd "${REPO_ROOT}"
case "${TARGET}" in
  wasm|wasm-lite|wasm-threaded)
    exec make "${TARGET}"
    ;;
  web)
    build_web_dist
    ;;
  sheet)
    build_sheet_dist gpu
    ;;
  sheet-lite)
    build_sheet_dist lite
    ;;
  report)
    build_report_dist
    ;;
  bundle)
    build_bundles
    ;;
  all)
    build_bundles
    build_web_dist
    build_sheet_dist gpu
    build_sheet_dist lite
    build_report_dist
    ;;
esac
