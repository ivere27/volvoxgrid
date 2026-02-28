#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  adb_swipe.sh [-s SERIAL] [X1 Y1 X2 Y2 [DURATION_MS]]

Defaults:
  SERIAL=auto-detect first connected device
  X1=540 Y1=1700 X2=540 Y2=700 DURATION_MS=350

Examples:
  adb_swipe.sh
  adb_swipe.sh -s <DEVICE_SERIAL>
  adb_swipe.sh -s <DEVICE_SERIAL> 540 1700 540 700 350
EOF
}

detect_serial() {
  adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }'
}

serial="${ADB_SERIAL:-}"
positionals=()

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
      positionals+=("$1")
      shift
      ;;
  esac
done

x1=540
y1=1700
x2=540
y2=700
duration_ms=350

if [[ ${#positionals[@]} -eq 4 || ${#positionals[@]} -eq 5 ]]; then
  x1="${positionals[0]}"
  y1="${positionals[1]}"
  x2="${positionals[2]}"
  y2="${positionals[3]}"
  if [[ ${#positionals[@]} -eq 5 ]]; then
    duration_ms="${positionals[4]}"
  fi
elif [[ ${#positionals[@]} -ne 0 ]]; then
  echo "Expected 0, 4, or 5 coordinate arguments; got ${#positionals[@]}" >&2
  usage >&2
  exit 1
fi

if [[ -z "$serial" ]]; then
  serial="$(detect_serial || true)"
fi

adb_cmd=(adb)
if [[ -n "$serial" ]]; then
  adb_cmd+=(-s "$serial")
else
  echo "No device serial provided and no connected device detected." >&2
  exit 1
fi

"${adb_cmd[@]}" shell input swipe "$x1" "$y1" "$x2" "$y2" "$duration_ms"
echo "swipe:$x1,$y1->$x2,$y2 duration=${duration_ms}ms"
