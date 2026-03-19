#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: scripts/run_headless_bench_matrix.sh [--runs N] [--profile debug|release] [--no-build] [--] [headless_bench args...]

Defaults:
  runs: 5
  profile: release
  benchmark args: headless_bench defaults (renderer=both, scroll_blit=both)

Examples:
  scripts/run_headless_bench_matrix.sh
  scripts/run_headless_bench_matrix.sh --runs 3 -- --width 1920 --height 1080
  scripts/run_headless_bench_matrix.sh -- --renderer gpu --scroll-blit-mode both

Any args after `--` are passed directly to `headless_bench`.
EOF
  exit 2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Error: required command not found: ${cmd}" >&2
    exit 2
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

RUNS=5
PROFILE="release"
NO_BUILD=0
BENCH_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      [[ $# -ge 2 ]] || usage
      RUNS="$2"
      shift 2
      ;;
    --profile)
      [[ $# -ge 2 ]] || usage
      PROFILE="$2"
      shift 2
      ;;
    --no-build)
      NO_BUILD=1
      shift
      ;;
    --help|-h)
      usage
      ;;
    --)
      shift
      BENCH_ARGS=("$@")
      break
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage
      ;;
  esac
done

case "${PROFILE}" in
  debug|release) ;;
  *)
    echo "Error: profile must be 'debug' or 'release', got '${PROFILE}'." >&2
    exit 2
    ;;
esac

if ! [[ "${RUNS}" =~ ^[0-9]+$ ]] || [[ "${RUNS}" -le 0 ]]; then
  echo "Error: runs must be a positive integer, got '${RUNS}'." >&2
  exit 2
fi

require_cmd awk
require_cmd mktemp
require_cmd tee

cd "${REPO_ROOT}"

if [[ "${PROFILE}" == "release" ]]; then
  BUILD_FLAGS=(--release)
else
  BUILD_FLAGS=()
fi

PLUGIN_PATH="${REPO_ROOT}/target/${PROFILE}/libvolvoxgrid_plugin.so"
BENCH_BIN="${REPO_ROOT}/target/${PROFILE}/headless_bench"
RUN_ARGS=("${BENCH_ARGS[@]}")

if [[ "${NO_BUILD}" -eq 0 ]]; then
  require_cmd cargo
  echo "Building plugin (${PROFILE})..."
  cargo build "${BUILD_FLAGS[@]}" -p volvoxgrid-plugin --features gpu
  echo "Building headless benchmark (${PROFILE})..."
  cargo build "${BUILD_FLAGS[@]}" -p volvoxgrid-gtk-test --bin headless_bench
fi

if [[ ! -f "${PLUGIN_PATH}" ]]; then
  echo "Error: plugin library not found: ${PLUGIN_PATH}" >&2
  echo "Set VOLVOXGRID_PLUGIN_PATH manually or rerun without --no-build." >&2
  exit 1
fi

if [[ ! -x "${BENCH_BIN}" ]]; then
  echo "Error: benchmark binary not found: ${BENCH_BIN}" >&2
  echo "Rerun without --no-build or build volvoxgrid-gtk-test first." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

SUMMARY_FILE="${TMP_DIR}/summary-lines.txt"

echo
echo "Running ${RUNS} benchmark iteration(s)..."
echo "Plugin: ${PLUGIN_PATH}"
echo "Binary: ${BENCH_BIN}"
echo "Args: ${RUN_ARGS[*]}"

for run in $(seq 1 "${RUNS}"); do
  LOG_FILE="${TMP_DIR}/run-${run}.log"
  echo
  echo "===== run ${run}/${RUNS} ====="

  set +e
  VOLVOXGRID_PLUGIN_PATH="${PLUGIN_PATH}" "${BENCH_BIN}" "${RUN_ARGS[@]}" | tee "${LOG_FILE}"
  STATUS=${PIPESTATUS[0]}
  set -e

  if [[ "${STATUS}" -ne 0 ]]; then
    echo "Error: benchmark run ${run} failed with exit code ${STATUS}." >&2
    echo "Log: ${LOG_FILE}" >&2
    exit "${STATUS}"
  fi

  RUN_SUMMARY="$(awk '
    /^== summary ==$/ { in_summary = 1; next }
    in_summary && NF == 0 { in_summary = 0 }
    in_summary { print }
  ' "${LOG_FILE}")"

  if [[ -z "${RUN_SUMMARY}" ]]; then
    RUN_SUMMARY="$(grep '^renderer=' "${LOG_FILE}" || true)"
  fi

  if [[ -z "${RUN_SUMMARY}" ]]; then
    echo "Error: no summary lines found in ${LOG_FILE}." >&2
    exit 1
  fi

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    printf 'run=%d %s\n' "${run}" "${line}" >> "${SUMMARY_FILE}"
  done <<< "${RUN_SUMMARY}"
done

echo
echo "===== aggregate across ${RUNS} run(s) ====="

awk '
  function strip_ms(value) {
    sub(/ms$/, "", value)
    return value + 0
  }

  function add_metric(case_key, metric, value, key) {
    key = case_key SUBSEP metric
    sum[key] += value
    count[key] += 1
    if (!(key in min) || value < min[key]) {
      min[key] = value
    }
    if (!(key in max) || value > max[key]) {
      max[key] = value
    }
  }

  BEGIN {
    metric_names[1] = "steady_avg"
    metric_names[2] = "fling_avg"
    metric_names[3] = "combined_avg"
    metric_names[4] = "combined_p95"
    metric_names[5] = "combined_max"
  }

  {
    delete kv
    for (i = 1; i <= NF; i++) {
      split($i, part, "=")
      key = part[1]
      value = substr($i, length(key) + 2)
      kv[key] = value
    }

    case_key = "renderer=" kv["renderer"] " scroll_blit=" kv["scroll_blit"]
    if (!(case_key in seen_case)) {
      seen_case[case_key] = 1
      order[++case_count] = case_key
    }

    actual_counts[case_key SUBSEP kv["actual"]] += 1

    add_metric(case_key, "steady_avg", strip_ms(kv["steady_avg"]))
    add_metric(case_key, "fling_avg", strip_ms(kv["fling_avg"]))
    add_metric(case_key, "combined_avg", strip_ms(kv["combined_avg"]))
    add_metric(case_key, "combined_p95", strip_ms(kv["combined_p95"]))
    add_metric(case_key, "combined_max", strip_ms(kv["combined_max"]))
  }

  END {
    split("cpu gpu mixed none", actual_modes, " ")

    for (idx = 1; idx <= case_count; idx++) {
      case_key = order[idx]
      print case_key

      printf "  actual:"
      first = 1
      for (mode_idx = 1; mode_idx <= 4; mode_idx++) {
        mode = actual_modes[mode_idx]
        count_key = case_key SUBSEP mode
        if (actual_counts[count_key] > 0) {
          printf "%s%s=%d", first ? " " : ", ", mode, actual_counts[count_key]
          first = 0
        }
      }
      if (first) {
        printf " none=0"
      }
      printf "\n"

      for (metric_idx = 1; metric_idx <= 5; metric_idx++) {
        metric = metric_names[metric_idx]
        key = case_key SUBSEP metric
        printf "  %-13s avg=%8.3fms min=%8.3fms max=%8.3fms\n",
          metric,
          sum[key] / count[key],
          min[key],
          max[key]
      }

      printf "\n"
    }
  }
' "${SUMMARY_FILE}"
