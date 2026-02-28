#!/bin/bash
# run_compare_data.sh — Run data-oriented comparison scenarios
#
# Uses the regular grid_compare_test pipeline but points to tests_data and
# defaults to data test IDs unless the caller passes --test/--tests.
#
# Usage:
#   ./run_compare_data.sh [--only-vv] [--no-diff] [--no-html] [--test N] [--tests LIST]

set -euo pipefail
cd "$(dirname "$0")"

DATA_TESTS_DIR="${TESTS_DIR_DATA:-./tests_data}"
DEFAULT_FILTER="${DATA_TEST_FILTER:-66-67}"
ARGS=("$@")
HAS_FILTER=0

for arg in "${ARGS[@]}"; do
    case "$arg" in
        --test|--tests|--test=*|--tests=*)
            HAS_FILTER=1
            ;;
    esac
done

if [ ! -d "$DATA_TESTS_DIR" ]; then
    echo "ERROR: data tests directory not found: $DATA_TESTS_DIR"
    exit 1
fi

if [ "$HAS_FILTER" -eq 0 ]; then
    ARGS+=(--tests "$DEFAULT_FILTER")
fi

echo "=== Grid Compare (Data Patterns) ==="
echo "Using data test scripts: $DATA_TESTS_DIR"
if [ "$HAS_FILTER" -eq 0 ]; then
    echo "Default test filter: $DEFAULT_FILTER"
fi
echo ""

TESTS_DIR_UI="$DATA_TESTS_DIR" ./run_compare_ui.sh "${ARGS[@]}"
