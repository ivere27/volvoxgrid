#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "Usage: $0 <platform> <native-library> <symbols-output-dir>" >&2
  exit 2
fi

PLATFORM="$1"
BINARY="$2"
OUT_DIR="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${BINARY}" ]]; then
  echo "Warning: native library not found for debug symbols: ${BINARY}" >&2
  exit 0
fi

mkdir -p "${OUT_DIR}"

split_with_objcopy() {
  local objcopy_cmd="$1"
  local debug_file="${OUT_DIR}/$(basename "${BINARY}").debug"

  if ! command -v "${objcopy_cmd}" >/dev/null 2>&1; then
    echo "Warning: ${objcopy_cmd} not found; keeping native library unmodified: ${BINARY}" >&2
    return 0
  fi

  strip_packaged_binary() {
    if ! "${objcopy_cmd}" --strip-debug --strip-unneeded "${BINARY}"; then
      echo "Warning: failed to strip packaged native library: ${BINARY}" >&2
      return 1
    fi
    return 0
  }

  rm -f "${debug_file}"
  if ! "${objcopy_cmd}" --only-keep-debug "${BINARY}" "${debug_file}"; then
    echo "Warning: failed to extract debug symbols from ${BINARY}" >&2
    rm -f "${debug_file}"
    strip_packaged_binary || true
    return 0
  fi

  if [[ ! -s "${debug_file}" ]]; then
    echo "Warning: extracted debug symbols are empty for ${BINARY}" >&2
    rm -f "${debug_file}"
    strip_packaged_binary || true
    return 0
  fi

  if ! strip_packaged_binary; then
    return 0
  fi

  "${objcopy_cmd}" --add-gnu-debuglink="${debug_file}" "${BINARY}" >/dev/null 2>&1 || true
  echo "Split debug symbols: ${BINARY} -> ${debug_file}"
}

case "${PLATFORM}" in
  linux-*|android-*)
    if command -v llvm-objcopy >/dev/null 2>&1; then
      split_with_objcopy llvm-objcopy
    else
      split_with_objcopy objcopy
    fi
    ;;
  windows-x86)
    split_with_objcopy i686-w64-mingw32-objcopy
    ;;
  windows-x86_64)
    split_with_objcopy x86_64-w64-mingw32-objcopy
    ;;
  macos-*)
    if command -v dsymutil >/dev/null 2>&1; then
      dsymutil "${BINARY}" -o "${OUT_DIR}/$(basename "${BINARY}").dSYM" >/dev/null 2>&1 || \
        echo "Warning: dsymutil failed for ${BINARY}" >&2
    elif command -v llvm-dsymutil >/dev/null 2>&1; then
      llvm-dsymutil "${BINARY}" -o "${OUT_DIR}/$(basename "${BINARY}").dSYM" >/dev/null 2>&1 || \
        echo "Warning: llvm-dsymutil failed for ${BINARY}" >&2
    else
      echo "Warning: dsymutil not found; no dSYM produced for ${BINARY}" >&2
    fi
    bash "${SCRIPT_DIR}/strip_macos_dylibs.sh" "${BINARY}"
    ;;
  *)
    echo "Warning: unsupported debug-symbol platform '${PLATFORM}' for ${BINARY}" >&2
    ;;
esac
