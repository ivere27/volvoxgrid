#!/usr/bin/env bash
set -euo pipefail

# iOS static library build script — runs inside Docker (Dockerfile.ios).
#
# Cross-compiles the Rust volvoxgrid native library as a static library (.a) for
# iOS device (arm64) and simulator (arm64 + x86_64), then creates an
# XCFramework-style directory layout.
#
# Usage (inside Docker): /opt/volvoxgrid/build_ios.sh

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
VERSION="${VERSION:-0.8.9}"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/ios}"
LIBRARY_BUILD_MODE="${LIBRARY_BUILD_MODE:-full}"
BUILD_DEBUG_SYMBOLS="${BUILD_DEBUG_SYMBOLS:-1}"
DEBUG_SYMBOLS_DIR="${DEBUG_SYMBOLS_DIR:-${REPO_ROOT}/dist/symbols}"

case "${LIBRARY_BUILD_MODE}" in
  full)
    LIBRARY_FEATURE_ARGS=()
    XCFW_NAME="VolvoxGrid"
    ;;
  lite)
    LIBRARY_FEATURE_ARGS=(--no-default-features --features demo)
    XCFW_NAME="VolvoxGridLite"
    ;;
  *)
    echo "Error: LIBRARY_BUILD_MODE must be 'full' or 'lite', got '${LIBRARY_BUILD_MODE}'." >&2
    exit 1
    ;;
esac

detect_cpu_count() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
    return
  fi
  if command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN
    return
  fi
  echo 1
}

CPU_COUNT="$(detect_cpu_count)"
DEFAULT_BUILD_JOBS=$(( CPU_COUNT > 2 ? CPU_COUNT - 2 : 1 ))
BUILD_JOBS="${BUILD_JOBS:-${DEFAULT_BUILD_JOBS}}"
if ! [[ "${BUILD_JOBS}" =~ ^[0-9]+$ ]] || [[ "${BUILD_JOBS}" -lt 1 ]]; then
  echo "Error: BUILD_JOBS must be a positive integer, got '${BUILD_JOBS}'." >&2
  exit 1
fi
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-${BUILD_JOBS}}"
echo "Using BUILD_JOBS=${BUILD_JOBS} (cpu=${CPU_COUNT}, cargo=${CARGO_BUILD_JOBS})"
echo "Using LIBRARY_BUILD_MODE=${LIBRARY_BUILD_MODE} (${XCFW_NAME}.xcframework)"
echo "Using BUILD_DEBUG_SYMBOLS=${BUILD_DEBUG_SYMBOLS}"

# Metadata consumed by engine/build.rs for embedding into binaries.
export VOLVOXGRID_VERSION="${VOLVOXGRID_VERSION:-${VERSION}}"
export VOLVOXGRID_GIT_COMMIT="${VOLVOXGRID_GIT_COMMIT:-${GIT_COMMIT}}"
export VOLVOXGRID_BUILD_DATE="${VOLVOXGRID_BUILD_DATE:-${BUILD_DATE}}"

LIBRARY_CRATE="${REPO_ROOT}/runtime"
if [[ ! -f "${LIBRARY_CRATE}/Cargo.toml" ]]; then
  echo "Error: native library crate not found at ${LIBRARY_CRATE}" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d /tmp/volvoxgrid-ios-XXXXXX)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

should_build_debug_symbols() {
  case "${BUILD_DEBUG_SYMBOLS}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
  esac
  return 1
}

CARGO_RELEASE_ARGS=(-j "${CARGO_BUILD_JOBS}" --release)
if should_build_debug_symbols; then
  CARGO_RELEASE_ARGS+=(--config 'profile.release.debug="line-tables-only"')
  CARGO_RELEASE_ARGS+=(--config 'profile.release.strip="none"')
fi

strip_static_archive() {
  local archive="$1"

  if ! command -v llvm-strip >/dev/null 2>&1; then
    echo "Warning: llvm-strip not found; keeping iOS archive unstripped: ${archive}" >&2
    return 0
  fi

  # Strip DWARF and local symbols from the distributable archive while preserving
  # global symbols needed by the final app link.
  if ! llvm-strip --strip-debug --discard-all "${archive}"; then
    echo "Warning: failed to strip iOS archive: ${archive}" >&2
    return 0
  fi
}

capture_static_archive_symbols() {
  local slice="$1"
  local archive="$2"
  local root="${WORK_DIR}/debug-symbols/${XCFW_NAME}-${VERSION}-debug-symbols"
  local out_dir="${root}/ios/${slice}"

  if ! should_build_debug_symbols || [[ ! -f "${archive}" ]]; then
    return 0
  fi

  mkdir -p "${out_dir}"
  cp -f "${archive}" "${out_dir}/libvolvoxgrid.a.unstripped"
}

finalize_debug_symbols() {
  if ! should_build_debug_symbols; then
    return 0
  fi

  local root="${WORK_DIR}/debug-symbols/${XCFW_NAME}-${VERSION}-debug-symbols"
  if [[ ! -d "${root}" ]] || ! find "${root}" -mindepth 1 -print -quit | grep -q .; then
    echo "No iOS debug symbols captured for ${XCFW_NAME}-${VERSION}."
    return 0
  fi

  mkdir -p "${root}/META-INF/volvoxgrid" "${DEBUG_SYMBOLS_DIR}"
  cat > "${root}/META-INF/volvoxgrid/build-info.properties" <<META
volvoxgrid.version=${VERSION}
volvoxgrid.artifact_id=${XCFW_NAME}
volvoxgrid.git_commit=${GIT_COMMIT}
volvoxgrid.build_date=${BUILD_DATE}
META

  local zip_path
  zip_path="$(cd "${DEBUG_SYMBOLS_DIR}" && pwd)/${XCFW_NAME}-${VERSION}-debug-symbols.zip"
  rm -f "${zip_path}"
  (cd "$(dirname "${root}")" && zip -qr "${zip_path}" "$(basename "${root}")")
  echo "Built iOS debug symbols: ${zip_path}"
}

# ── Build static libraries for each iOS target ─────────────────────────────

echo "Building library: aarch64-apple-ios (device, staticlib)..."
(cd "${LIBRARY_CRATE}" && cargo rustc "${CARGO_RELEASE_ARGS[@]}" --lib "${LIBRARY_FEATURE_ARGS[@]}" --target aarch64-apple-ios --crate-type staticlib)
DEVICE_LIB="${CARGO_TARGET_DIR}/aarch64-apple-ios/release/libvolvoxgrid.a"
if [[ ! -f "${DEVICE_LIB}" ]]; then
  echo "Error: device static lib not found: ${DEVICE_LIB}" >&2
  exit 1
fi

echo "Building library: aarch64-apple-ios-sim (simulator arm64, staticlib)..."
(cd "${LIBRARY_CRATE}" && cargo rustc "${CARGO_RELEASE_ARGS[@]}" --lib "${LIBRARY_FEATURE_ARGS[@]}" --target aarch64-apple-ios-sim --crate-type staticlib)
SIM_ARM64_LIB="${CARGO_TARGET_DIR}/aarch64-apple-ios-sim/release/libvolvoxgrid.a"
if [[ ! -f "${SIM_ARM64_LIB}" ]]; then
  echo "Error: simulator arm64 static lib not found: ${SIM_ARM64_LIB}" >&2
  exit 1
fi

echo "Building library: x86_64-apple-ios (simulator x86_64, staticlib)..."
(cd "${LIBRARY_CRATE}" && cargo rustc "${CARGO_RELEASE_ARGS[@]}" --lib "${LIBRARY_FEATURE_ARGS[@]}" --target x86_64-apple-ios --crate-type staticlib)
SIM_X64_LIB="${CARGO_TARGET_DIR}/x86_64-apple-ios/release/libvolvoxgrid.a"
if [[ ! -f "${SIM_X64_LIB}" ]]; then
  echo "Error: simulator x86_64 static lib not found: ${SIM_X64_LIB}" >&2
  exit 1
fi

# ── Create simulator universal binary ───────────────────────────────────────
echo "Creating simulator universal binary (arm64 + x86_64)..."
SIM_UNIVERSAL="${WORK_DIR}/libvolvoxgrid_sim.a"

# Use ar to merge both archives into one
SIM_MERGE_DIR="${WORK_DIR}/sim-merge"
mkdir -p "${SIM_MERGE_DIR}/arm64" "${SIM_MERGE_DIR}/x86_64"
(cd "${SIM_MERGE_DIR}/arm64" && ar x "${SIM_ARM64_LIB}")
(cd "${SIM_MERGE_DIR}/x86_64" && ar x "${SIM_X64_LIB}")

# Prefix x86_64 object files to avoid name collisions
for f in "${SIM_MERGE_DIR}/x86_64"/*.o; do
  [[ -f "$f" ]] || continue
  mv "$f" "${SIM_MERGE_DIR}/x86_64/x64_$(basename "$f")"
done

ar crs "${SIM_UNIVERSAL}" "${SIM_MERGE_DIR}/arm64"/*.o "${SIM_MERGE_DIR}/x86_64"/*.o

# ── Create XCFramework structure ────────────────────────────────────────────
echo "Creating XCFramework directory structure..."
XCFW_DIR="${DIST_DIR}/${XCFW_NAME}.xcframework"
rm -rf "${XCFW_DIR}"

# Device slice
DEVICE_DIR="${XCFW_DIR}/ios-arm64"
mkdir -p "${DEVICE_DIR}"
cp "${DEVICE_LIB}" "${DEVICE_DIR}/libvolvoxgrid.a"
capture_static_archive_symbols "ios-arm64" "${DEVICE_DIR}/libvolvoxgrid.a"
strip_static_archive "${DEVICE_DIR}/libvolvoxgrid.a"

# Simulator slice (universal arm64 + x86_64)
SIM_DIR="${XCFW_DIR}/ios-arm64_x86_64-simulator"
mkdir -p "${SIM_DIR}"
cp "${SIM_UNIVERSAL}" "${SIM_DIR}/libvolvoxgrid.a"
capture_static_archive_symbols "ios-arm64_x86_64-simulator" "${SIM_DIR}/libvolvoxgrid.a"
strip_static_archive "${SIM_DIR}/libvolvoxgrid.a"

# ── Generate C header ──────────────────────────────────────────────────────
HEADER_FILE="${DIST_DIR}/volvoxgrid.h"
cat > "${HEADER_FILE}" <<'HEADER'
#ifndef VOLVOXGRID_H
#define VOLVOXGRID_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Synurang FFI runtime entry points.
char *Synurang_Invoke_VolvoxGridService(
    const char *method,
    const char *data,
    int32_t data_len,
    int32_t *resp_len
);

void Synurang_Free(void *ptr);

uint64_t Synurang_Stream_VolvoxGridService_Open(const char *method);

int32_t Synurang_Stream_Send(
    uint64_t handle,
    const char *data,
    int32_t data_len
);

char *Synurang_Stream_Recv(
    uint64_t handle,
    int32_t *resp_len,
    int32_t *status
);

void Synurang_Stream_CloseSend(uint64_t handle);

void Synurang_Stream_Close(uint64_t handle);

#ifdef __cplusplus
}
#endif

#endif // VOLVOXGRID_H
HEADER

MODULEMAP_FILE="${WORK_DIR}/module.modulemap"
cat > "${MODULEMAP_FILE}" <<MODULEMAP
module ${XCFW_NAME} {
  header "volvoxgrid.h"
  export *
  link framework "CoreFoundation"
  link framework "CoreGraphics"
  link framework "CoreText"
}
MODULEMAP

# ── Generate Info.plist for XCFramework ─────────────────────────────────────
cat > "${XCFW_DIR}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundlePackageType</key>
  <string>XFWK</string>
  <key>XCFrameworkFormatVersion</key>
  <string>1.0</string>
  <key>AvailableLibraries</key>
  <array>
    <dict>
      <key>LibraryIdentifier</key>
      <string>ios-arm64</string>
      <key>LibraryPath</key>
      <string>libvolvoxgrid.a</string>
      <key>HeadersPath</key>
      <string>Headers</string>
      <key>SupportedArchitectures</key>
      <array>
        <string>arm64</string>
      </array>
      <key>SupportedPlatform</key>
      <string>ios</string>
    </dict>
    <dict>
      <key>LibraryIdentifier</key>
      <string>ios-arm64_x86_64-simulator</string>
      <key>LibraryPath</key>
      <string>libvolvoxgrid.a</string>
      <key>HeadersPath</key>
      <string>Headers</string>
      <key>SupportedArchitectures</key>
      <array>
        <string>arm64</string>
        <string>x86_64</string>
      </array>
      <key>SupportedPlatform</key>
      <string>ios</string>
      <key>SupportedPlatformVariant</key>
      <string>simulator</string>
    </dict>
  </array>
</dict>
</plist>
PLIST

# Copy header into each slice's Headers/ directory
mkdir -p "${DEVICE_DIR}/Headers" "${SIM_DIR}/Headers"
cp "${HEADER_FILE}" "${DEVICE_DIR}/Headers/"
cp "${HEADER_FILE}" "${SIM_DIR}/Headers/"
cp "${MODULEMAP_FILE}" "${DEVICE_DIR}/Headers/module.modulemap"
cp "${MODULEMAP_FILE}" "${SIM_DIR}/Headers/module.modulemap"

finalize_debug_symbols

echo ""
echo "Built iOS artifacts:"
echo "  ${XCFW_DIR}/"
echo "    ios-arm64/libvolvoxgrid.a"
echo "    ios-arm64_x86_64-simulator/libvolvoxgrid.a"
echo "  ${HEADER_FILE}"
echo "  module ${XCFW_NAME}"
if should_build_debug_symbols && [[ -f "${DEBUG_SYMBOLS_DIR}/${XCFW_NAME}-${VERSION}-debug-symbols.zip" ]]; then
  echo "  ${DEBUG_SYMBOLS_DIR}/${XCFW_NAME}-${VERSION}-debug-symbols.zip"
fi
