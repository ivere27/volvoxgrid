#!/usr/bin/env bash
set -euo pipefail

# iOS static library build script — runs inside Docker (Dockerfile.ios).
#
# Cross-compiles the Rust volvoxgrid plugin as a static library (.a) for
# iOS device (arm64) and simulator (arm64 + x86_64), then creates an
# XCFramework-style directory layout.
#
# Usage (inside Docker): /opt/volvoxgrid/build_ios.sh

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
VERSION="${VERSION:-0.3.0}"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/ios}"

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

# Metadata consumed by engine/build.rs for embedding into binaries.
export VOLVOXGRID_VERSION="${VOLVOXGRID_VERSION:-${VERSION}}"
export VOLVOXGRID_GIT_COMMIT="${VOLVOXGRID_GIT_COMMIT:-${GIT_COMMIT}}"
export VOLVOXGRID_BUILD_DATE="${VOLVOXGRID_BUILD_DATE:-${BUILD_DATE}}"

PLUGIN_CRATE="${REPO_ROOT}/plugin"
if [[ ! -f "${PLUGIN_CRATE}/Cargo.toml" ]]; then
  echo "Error: plugin crate not found at ${PLUGIN_CRATE}" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d /tmp/volvoxgrid-ios-XXXXXX)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

# ── Build static libraries for each iOS target ─────────────────────────────

echo "Building plugin: aarch64-apple-ios (device, staticlib)..."
(cd "${PLUGIN_CRATE}" && cargo rustc -j "${CARGO_BUILD_JOBS}" --release --lib --target aarch64-apple-ios --crate-type staticlib)
DEVICE_LIB="${CARGO_TARGET_DIR}/aarch64-apple-ios/release/libvolvoxgrid_plugin.a"
if [[ ! -f "${DEVICE_LIB}" ]]; then
  echo "Error: device static lib not found: ${DEVICE_LIB}" >&2
  exit 1
fi

echo "Building plugin: aarch64-apple-ios-sim (simulator arm64, staticlib)..."
(cd "${PLUGIN_CRATE}" && cargo rustc -j "${CARGO_BUILD_JOBS}" --release --lib --target aarch64-apple-ios-sim --crate-type staticlib)
SIM_ARM64_LIB="${CARGO_TARGET_DIR}/aarch64-apple-ios-sim/release/libvolvoxgrid_plugin.a"
if [[ ! -f "${SIM_ARM64_LIB}" ]]; then
  echo "Error: simulator arm64 static lib not found: ${SIM_ARM64_LIB}" >&2
  exit 1
fi

echo "Building plugin: x86_64-apple-ios (simulator x86_64, staticlib)..."
(cd "${PLUGIN_CRATE}" && cargo rustc -j "${CARGO_BUILD_JOBS}" --release --lib --target x86_64-apple-ios --crate-type staticlib)
SIM_X64_LIB="${CARGO_TARGET_DIR}/x86_64-apple-ios/release/libvolvoxgrid_plugin.a"
if [[ ! -f "${SIM_X64_LIB}" ]]; then
  echo "Error: simulator x86_64 static lib not found: ${SIM_X64_LIB}" >&2
  exit 1
fi

# ── Create simulator universal binary ───────────────────────────────────────
echo "Creating simulator universal binary (arm64 + x86_64)..."
SIM_UNIVERSAL="${WORK_DIR}/libvolvoxgrid_plugin_sim.a"

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
XCFW_DIR="${DIST_DIR}/VolvoxGridPlugin.xcframework"
rm -rf "${XCFW_DIR}"

# Device slice
DEVICE_DIR="${XCFW_DIR}/ios-arm64"
mkdir -p "${DEVICE_DIR}"
cp "${DEVICE_LIB}" "${DEVICE_DIR}/libvolvoxgrid_plugin.a"

# Simulator slice (universal arm64 + x86_64)
SIM_DIR="${XCFW_DIR}/ios-arm64_x86_64-simulator"
mkdir -p "${SIM_DIR}"
cp "${SIM_UNIVERSAL}" "${SIM_DIR}/libvolvoxgrid_plugin.a"

# ── Generate C header ──────────────────────────────────────────────────────
HEADER_FILE="${DIST_DIR}/volvoxgrid_plugin.h"
cat > "${HEADER_FILE}" <<'HEADER'
#ifndef VOLVOXGRID_PLUGIN_H
#define VOLVOXGRID_PLUGIN_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Synurang FFI plugin entry points
int32_t synurang_plugin_call(
    int32_t service_id,
    int32_t method_id,
    const uint8_t *input_buf,
    size_t input_len,
    uint8_t **output_buf,
    size_t *output_len
);

void synurang_plugin_free(uint8_t *buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif // VOLVOXGRID_PLUGIN_H
HEADER

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
      <string>libvolvoxgrid_plugin.a</string>
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
      <string>libvolvoxgrid_plugin.a</string>
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

echo ""
echo "Built iOS artifacts:"
echo "  ${XCFW_DIR}/"
echo "    ios-arm64/libvolvoxgrid_plugin.a"
echo "    ios-arm64_x86_64-simulator/libvolvoxgrid_plugin.a"
echo "  ${HEADER_FILE}"
