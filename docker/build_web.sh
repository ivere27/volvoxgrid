#!/usr/bin/env bash
set -euo pipefail

# Web build dispatcher for Dockerfile.web.
# Produces non-server dist artifacts and web bundles.

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
TARGET="${WEB_DOCKER_TARGET:-all}"
if [[ -z "${VOLVOXGRID_VERSION:-}" && -z "${VERSION:-}" && -f "${REPO_ROOT}/VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION")"
fi
VERSION="${VOLVOXGRID_VERSION:-${VERSION:-}}"
if [[ -z "${VERSION}" ]]; then
  echo "Error: VERSION is empty. Set VOLVOXGRID_VERSION, VERSION, or populate ${REPO_ROOT}/VERSION." >&2
  exit 1
fi
export WASM_PACK_OPT_FLAGS="${WASM_PACK_OPT_FLAGS-}"
WASM_DIST_ROOT="${REPO_ROOT}/dist/wasm"
WASM_LITE_DIST_ROOT="${REPO_ROOT}/dist/wasm-lite"
WEB_DIST_ROOT="${REPO_ROOT}/dist/web"
PAGES_BASE_PATH="${PAGES_BASE_PATH:-/volvoxgrid/}"
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

inject_firebase_analytics() {
  python3 "${REPO_ROOT}/scripts/inject_firebase_analytics.py" "$1"
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
    importmap_vg="${cdn_base}/volvoxgrid@${VERSION}/dist/volvoxgrid.min.js"
    wasm_url="${cdn_base}/${wasm_pkg}@${VERSION}/wasm/volvoxgrid_wasm.js"
    sheet_url="${cdn_base}/@volvoxgrid/sheet@${VERSION}/dist/volvox-sheet.min.js"
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
      if (typeof wasm.init_v1_runtime === "function") {
        wasm.init_v1_runtime();
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
    VITE_WASM_URL="${WASM_CDN_URL}" \
      VITE_VG_INITIAL_SCALE="${WEB_SCALE:-1.0}" \
      VITE_VG_EXTERNAL=1 \
      VITE_VG_VERSION="${VERSION}" \
      npm run build -- --base /demos/web/
  )
  copy_dir_clean "${REPO_ROOT}/web/example/dist" "${WEB_DIST_ROOT}/demos/web"
  copy_dir_clean "${REPO_ROOT}/web/example/wasm" "${WEB_DIST_ROOT}/demos/web/wasm"
  if [[ -d "${REPO_ROOT}/web/example/public/doom" ]]; then
    copy_dir_clean "${REPO_ROOT}/web/example/public/doom" "${WEB_DIST_ROOT}/demos/web/doom"
  fi
  inject_firebase_analytics "${WEB_DIST_ROOT}/demos/web/index.html"
  echo "Built web dist: ${WEB_DIST_ROOT}/demos/web"
}

build_pages_dist() {
  # Bundle the JS and WASM from this checkout so the released demo does not
  # depend on the corresponding npm packages having propagated to a CDN.
  make wasm
  (
    cd "${REPO_ROOT}/web/example"
    npm ci
    VITE_WASM_URL="${PAGES_BASE_PATH%/}/demos/web/wasm/volvoxgrid_wasm.js" \
      VITE_VG_INITIAL_SCALE="${WEB_SCALE:-1.0}" \
      VITE_VG_EXTERNAL=0 \
      npm run build -- --base "${PAGES_BASE_PATH%/}/demos/web/"
  )
  local pages_dir="${TMP_ROOT}/pages"
  local demo_dir="${pages_dir}/demos/web"
  local zip_path="${WEB_DIST_ROOT}/volvoxgrid-demo-${VERSION}.zip"
  mkdir -p "${demo_dir}/wasm"
  cp -RL "${REPO_ROOT}/web/example/dist/." "${demo_dir}/"
  cp -RL "${REPO_ROOT}/web/example/wasm/." "${demo_dir}/wasm/"
  inject_firebase_analytics "${demo_dir}/index.html"

  # Include sheet and sheet-lite demos
  build_sheet_dist gpu
  build_sheet_dist lite
  mkdir -p "${pages_dir}/demos/sheet" "${pages_dir}/demos/sheet-lite"
  cp -RL "${WEB_DIST_ROOT}/demos/sheet/." "${pages_dir}/demos/sheet/"
  cp -RL "${WEB_DIST_ROOT}/demos/sheet-lite/." "${pages_dir}/demos/sheet-lite/"

  cat > "${pages_dir}/index.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>VolvoxGrid Demo Index</title>
  <style>
    :root {
      color-scheme: light;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }

    body {
      margin: 0;
      background: #f7f8fa;
      color: #1f2937;
    }

    main {
      max-width: 720px;
      margin: 40px auto;
      padding: 0 16px;
    }

    h1 {
      margin: 0 0 8px;
      font-size: 28px;
    }

    p {
      margin: 0 0 20px;
      color: #4b5563;
    }

    ul {
      margin: 0;
      padding: 0;
      list-style: none;
      display: grid;
      gap: 12px;
    }

    li {
      background: #ffffff;
      border: 1px solid #e5e7eb;
      border-radius: 10px;
      padding: 14px 16px;
    }

    a {
      color: #0f4cde;
      text-decoration: none;
      font-weight: 600;
      font-size: 18px;
    }

    a:hover {
      text-decoration: underline;
    }

    .desc {
      margin-top: 6px;
      font-size: 14px;
      color: #4b5563;
    }
  </style>
</head>
<body>
  <main>
    <h1>VolvoxGrid Demos</h1>
    <p>Simple entry page for VolvoxGrid demo apps.</p>

    <ul>
      <li>
        <a href="./demos/web/">Web Demo</a>
        <div class="desc">Grid showcase with runtime-selectable scenarios (stress, sales, hierarchy, and optional DOOM).</div>
      </li>
      <li>
        <a href="./demos/sheet/">Sheet Demo</a>
        <div class="desc">Spreadsheet-style demo built with VolvoxSheet and embedded font rendering.</div>
      </li>
      <li>
        <a href="./demos/sheet-lite/">Sheet Lite Demo</a>
        <div class="desc">Lightweight VolvoxSheet variant using browser font rendering.</div>
      </li>
    </ul>
  </main>
</body>
</html>
EOF
  inject_firebase_analytics "${pages_dir}/index.html"
  sed 's|href="./demos/|href="./|g' "${pages_dir}/index.html" > "${pages_dir}/demos/index.html"
  inject_firebase_analytics "${pages_dir}/demos/index.html"
  printf '%s\n' "${VERSION}" > "${pages_dir}/VERSION"
  touch "${pages_dir}/.nojekyll"
  ensure_dir "${WEB_DIST_ROOT}"
  rm -f "${zip_path}"
  (cd "${pages_dir}" && zip -qr "${zip_path}" .)
  echo "Built Pages release demo: ${zip_path}"
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
  inject_firebase_analytics "${out_dir}/index.html"
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
  all|bundle|web|pages|sheet|sheet-lite|report|wasm|wasm-lite|wasm-threaded)
    ;;
  *)
    echo "Error: unsupported WEB_DOCKER_TARGET='${TARGET}'." >&2
    echo "Valid values: all, bundle, web, pages, sheet, sheet-lite, report, wasm, wasm-lite, wasm-threaded" >&2
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
  pages)
    build_pages_dist
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
    build_pages_dist
    ;;
esac
