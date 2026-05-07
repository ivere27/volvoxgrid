#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ROOT_DIR="../../.."
TARGET_DIR="${ROOT_DIR}/target/ocx"
OCX32="${OCX32:-${TARGET_DIR}/VolvoxGrid_i686.ocx}"
OCX64="${OCX64:-${TARGET_DIR}/VolvoxGrid_x86_64.ocx}"
MODE="${1:-all}"
ROOT_ABS="$(cd "${ROOT_DIR}" && pwd)"

abs_file() {
    local dir
    local base
    dir="$(dirname "$1")"
    base="$(basename "$1")"
    printf '%s/%s\n' "$(cd "${dir}" && pwd)" "${base}"
}

OCX32_ABS="$(abs_file "${OCX32}")"
OCX64_ABS="$(abs_file "${OCX64}")"
PROBE32="${TMPDIR:-/tmp}/probe_container_contract_i686.exe"
PROBE64="${TMPDIR:-/tmp}/probe_container_contract_x86_64.exe"
cleanup() {
    rm -f "${PROBE32}" "${PROBE64}"
}
trap cleanup EXIT

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "missing required command: $1" >&2
        exit 2
    fi
}

need wine
need i686-w64-mingw32-gcc
need x86_64-w64-mingw32-gcc

echo "=== Build no-registration container contract probe ==="
i686-w64-mingw32-gcc -O2 -Wall -o "${PROBE32}" probe_container_contract.c -loleaut32 -lole32 -lgdi32 -luuid
x86_64-w64-mingw32-gcc -O2 -Wall -o "${PROBE64}" probe_container_contract.c -loleaut32 -lole32 -lgdi32 -luuid

echo "=== Probe 32-bit OCX container contract (${MODE}) ==="
if [ ! -f "${OCX32_ABS}" ]; then
    echo "missing 32-bit OCX: ${OCX32_ABS}" >&2
    exit 2
fi
(cd "${ROOT_ABS}" && wine "${PROBE32}" "${OCX32_ABS}" "${MODE}")

echo "=== Probe 64-bit OCX container contract (${MODE}) ==="
if [ ! -f "${OCX64_ABS}" ]; then
    echo "missing 64-bit OCX: ${OCX64_ABS}" >&2
    exit 2
fi
(cd "${ROOT_ABS}" && wine "${PROBE64}" "${OCX64_ABS}" "${MODE}")
