#!/usr/bin/env bash
set -euo pipefail

file_size_bytes() {
  if stat -c%s "$1" >/dev/null 2>&1; then
    stat -c%s "$1"
    return
  fi
  stat -f%z "$1"
}

strip_one() {
  local dylib="$1"
  local tmp="${dylib}.stripped"
  local before
  local after

  if [[ ! -f "${dylib}" ]]; then
    return 0
  fi

  if ! command -v llvm-strip >/dev/null 2>&1; then
    echo "Warning: llvm-strip not found; keeping macOS dylib unstripped: ${dylib}" >&2
    return 0
  fi

  before="$(file_size_bytes "${dylib}")"

  rm -f "${tmp}"
  if ! llvm-strip --strip-all -o "${tmp}" "${dylib}"; then
    echo "Warning: llvm-strip failed; keeping macOS dylib unstripped: ${dylib}" >&2
    rm -f "${tmp}"
    return 0
  fi

  mv -f "${tmp}" "${dylib}"

  after="$(file_size_bytes "${dylib}")"
  echo "Stripped macOS dylib: ${dylib} (${before} -> ${after} bytes)"
}

if [[ "$#" -eq 0 ]]; then
  echo "Usage: $0 <lib.dylib>..." >&2
  exit 2
fi

for dylib in "$@"; do
  strip_one "${dylib}"
done
