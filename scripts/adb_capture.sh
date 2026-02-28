#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  adb_capture.sh [-s SERIAL] [OUTPUT_PNG]

Examples:
  adb_capture.sh
  adb_capture.sh -s <DEVICE_SERIAL> /tmp/volvoxgrid_after_swipe.png
EOF
}

detect_serial() {
  adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }'
}

serial="${ADB_SERIAL:-}"
default_out_file="${ADB_CAPTURE_FILE:-/tmp/volvoxgrid_after_swipe.png}"
out_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--serial)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 1; }
      serial="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$out_file" ]]; then
        out_file="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$out_file" ]]; then
  out_file="$default_out_file"
fi

if [[ -z "$serial" ]]; then
  serial="$(detect_serial || true)"
fi

mkdir -p "$(dirname "$out_file")"

adb_cmd=(adb)
if [[ -n "$serial" ]]; then
  adb_cmd+=(-s "$serial")
else
  echo "No device serial provided and no connected device detected." >&2
  exit 1
fi

"${adb_cmd[@]}" exec-out screencap -p > "$out_file"
echo "$out_file"
