#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <expected-version> <artifact-or-dir> [more...]" >&2
  echo "Examples:" >&2
  echo "  $0 0.4.0-SNAPSHOT dist/maven/volvoxgrid-desktop-0.4.0-SNAPSHOT.jar" >&2
  echo "  $0 0.4.0-SNAPSHOT dist/ios/VolvoxGridPlugin.xcframework" >&2
  exit 2
}

if [[ $# -lt 2 ]]; then
  usage
fi

EXPECTED_VERSION="$1"
shift

if [[ -z "${EXPECTED_VERSION}" ]]; then
  echo "Error: expected version is empty." >&2
  exit 2
fi

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Error: required command not found: ${cmd}" >&2
    exit 2
  fi
}

require_cmd strings
require_cmd unzip

verify_binary_file() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "Error: binary file not found: ${file}" >&2
    return 1
  fi
  # Avoid grep -q in a pipe under pipefail: early grep exit can trip false negatives.
  if ! strings -a "${file}" | grep -F -- "${EXPECTED_VERSION}" >/dev/null; then
    echo "Error: version '${EXPECTED_VERSION}' not found in binary: ${file}" >&2
    return 1
  fi
  echo "OK: ${file}"
}

verify_zip_members() {
  local archive="$1"
  local member_regex="$2"
  local -a members=()

  if [[ ! -f "${archive}" ]]; then
    echo "Error: archive not found: ${archive}" >&2
    return 1
  fi

  mapfile -t members < <(unzip -Z1 "${archive}" | grep -E "${member_regex}" || true)
  if [[ ${#members[@]} -eq 0 ]]; then
    echo "Error: no native binaries matched in archive: ${archive}" >&2
    return 1
  fi

  local member
  for member in "${members[@]}"; do
    # Avoid grep -q in a pipe under pipefail: early grep exit can trip false negatives.
    if ! unzip -p "${archive}" "${member}" | strings -a | grep -F -- "${EXPECTED_VERSION}" >/dev/null; then
      echo "Error: version '${EXPECTED_VERSION}' not found in ${archive}:${member}" >&2
      return 1
    fi
  done

  echo "OK: ${archive} (${#members[@]} native binaries)"
}

verify_directory_binaries() {
  local dir="$1"
  local -a files=()
  mapfile -t files < <(find "${dir}" -type f \( -name '*.a' -o -name '*.so' -o -name '*.dll' -o -name '*.dylib' -o -name '*.ocx' \) | sort)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "Error: no native binaries found in directory: ${dir}" >&2
    return 1
  fi
  local f
  for f in "${files[@]}"; do
    verify_binary_file "${f}"
  done
}

for target in "$@"; do
  case "${target}" in
    *.aar)
      # Android AAR includes JNI bridge + engine plugin. Verify the plugin binary.
      verify_zip_members "${target}" '^jni/.+volvoxgrid_plugin(_lite)?\.(so|dll|dylib)$'
      ;;
    *.jar)
      # Desktop fat JAR embeds natives under native/<platform>/.
      verify_zip_members "${target}" '^native/.+\.(so|dll|dylib)$'
      ;;
    *.zip)
      # XCFramework zip and other packaged bundles.
      verify_zip_members "${target}" '^.+\.(a|so|dll|dylib|ocx)$'
      ;;
    *.a|*.so|*.dll|*.dylib|*.ocx)
      verify_binary_file "${target}"
      ;;
    *)
      if [[ -d "${target}" ]]; then
        verify_directory_binaries "${target}"
      else
        echo "Error: unsupported target (not file/dir with known type): ${target}" >&2
        exit 1
      fi
      ;;
  esac
done

echo "Version verification passed for expected version: ${EXPECTED_VERSION}"
