#!/bin/bash
# run_compare_ui.sh — Build & run grid comparison: FlexGrid vs VolvoxGrid
#
# Registers both OCXs in Wine, runs grid_compare_test.exe, converts
# output BMPs to PNG, and generates a side-by-side HTML report.
#
# Usage:
#   ./run_compare_ui.sh [--data] [--headless] [--no-headless] [--jobs N] [--only-vv] [--no-diff] [--no-html] [--test N] [--tests LIST]
#
# Headless mode:
#   - enabled by default via xvfb-run
#   - disable with --no-headless
#   - Xvfb screen can be customized via XVFB_SCREEN (default: 1920x1080x24)
#
# Parallel mode:
#   - `--jobs N` runs N wine workers in parallel by splitting selected tests
#   - default is max(CPU count - 2, 1)

set -euo pipefail
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="$(pwd)/$SCRIPT_PATH"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "$SCRIPT_PATH")"
cd "$SCRIPT_DIR"

REF_OCX_FILE="${REF_OCX_FILE:-../../../legacy/legacy_ocx.txt}"
REF_OCX_NAME=""
if [ -f "$REF_OCX_FILE" ]; then
    REF_OCX_NAME="$(sed -n '1p' "$REF_OCX_FILE" | tr -d '\r')"
fi
REF_OCX="../../../legacy/${REF_OCX_NAME}"
REF_PROGID_FILE="${REF_PROGID_FILE:-../../../legacy/legacy_progid.txt}"
REF_PROGID="${REF_PROGID:-}"
if [ -z "$REF_PROGID" ] && [ -f "$REF_PROGID_FILE" ]; then
    REF_PROGID="$(sed -n '1p' "$REF_PROGID_FILE" | tr -d '\r')"
fi
VOLVOX_OCX="../../../target/ocx/VolvoxGrid_i686.ocx"
TARGET_DIR="../../../target/ocx/compare"
OUT_DIR="$TARGET_DIR"
TESTS_DIR="${TESTS_DIR_UI:-./tests}"
TESTS_MODE="ui"
ARGS=()
NO_HTML=0
HAS_FILTER=0
DEFAULT_FILTER=""
HEADLESS=1
XVFB_SCREEN="${XVFB_SCREEN:-1920x1080x24}"
JOBS=0
JOBS_SET=0
WORKER_TIMEOUT_SEC="${WORKER_TIMEOUT_SEC:-60}"
SQL_COMPARE_TESTS="${SQL_COMPARE_TESTS:-84-103}"
# SQL-backed compare tests hang when multiple Wine/ADO workers run at once.
DEFAULT_PARALLEL_UNSAFE_TESTS="${DEFAULT_PARALLEL_UNSAFE_TESTS:-$SQL_COMPARE_TESTS}"
PARALLEL_UNSAFE_TESTS="${PARALLEL_UNSAFE_TESTS-$DEFAULT_PARALLEL_UNSAFE_TESTS}"
DEFAULT_NATIVE_WINEPREFIX="${DEFAULT_NATIVE_WINEPREFIX:-$HOME/.wine}"
DEFAULT_NATIVE_WINEDLLOVERRIDES="${DEFAULT_NATIVE_WINEDLLOVERRIDES:-msado15,msadce,msadco,msdart,msdaps,msdatl3,oledb32,msdadc,msdaenum,msdaer,msdasql,sqloledb,sqlsrv32,mtxdm,odbc32,odbccp32=n,b}"

ORIG_ARGS=("$@")

build_default_filter() {
    local dir="$1"
    local file base num
    local nums=()

    for file in "$dir"/*.vbs; do
        [ -f "$file" ] || continue
        base="$(basename "$file")"
        num="${base%%_*}"
        nums+=("$((10#$num))")
    done

    if [ "${#nums[@]}" -eq 0 ]; then
        return 1
    fi

    printf "%s\n" "${nums[@]}" | sort -n | paste -sd, -
}

filter_includes_test() {
    local filter="$1"
    local needle="$2"
    local tok a b t
    local IFS=","
    local tokens=()

    read -ra tokens <<< "$filter"
    for tok in "${tokens[@]}"; do
        tok="${tok//[[:space:]]/}"
        [ -z "$tok" ] && continue
        if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            a="${BASH_REMATCH[1]}"
            b="${BASH_REMATCH[2]}"
            if [ "$a" -gt "$b" ]; then
                t="$a"
                a="$b"
                b="$t"
            fi
            if [ "$needle" -ge "$a" ] && [ "$needle" -le "$b" ]; then
                return 0
            fi
        elif [[ "$tok" =~ ^[0-9]+$ ]] && [ "$tok" -eq "$needle" ]; then
            return 0
        fi
    done

    return 1
}

filter_includes_threshold() {
    local filter="$1"
    local threshold="$2"
    local tok a b t
    local IFS=","
    local tokens=()

    read -ra tokens <<< "$filter"
    for tok in "${tokens[@]}"; do
        tok="${tok//[[:space:]]/}"
        [ -z "$tok" ] && continue
        if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            a="${BASH_REMATCH[1]}"
            b="${BASH_REMATCH[2]}"
            if [ "$a" -gt "$b" ]; then
                t="$a"
                a="$b"
                b="$t"
            fi
            if [ "$b" -ge "$threshold" ]; then
                return 0
            fi
        elif [[ "$tok" =~ ^[0-9]+$ ]] && [ "$tok" -ge "$threshold" ]; then
            return 0
        fi
    done

    return 1
}

filters_overlap() {
    local filter_a="$1"
    local filter_b="$2"
    local tok a b t
    local IFS=","
    local tokens=()

    [ -n "$filter_a" ] || return 1
    [ -n "$filter_b" ] || return 1

    read -ra tokens <<< "$filter_b"
    for tok in "${tokens[@]}"; do
        tok="${tok//[[:space:]]/}"
        [ -z "$tok" ] && continue
        if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            a="${BASH_REMATCH[1]}"
            b="${BASH_REMATCH[2]}"
            if [ "$a" -gt "$b" ]; then
                t="$a"
                a="$b"
                b="$t"
            fi
            for ((t=a; t<=b; t++)); do
                if filter_includes_test "$filter_a" "$t"; then
                    return 0
                fi
            done
        elif [[ "$tok" =~ ^[0-9]+$ ]]; then
            if filter_includes_test "$filter_a" "$tok"; then
                return 0
            fi
        fi
    done

    return 1
}

run_compare_worker() {
    if [ "$WORKER_TIMEOUT_SEC" -gt 0 ] && command -v timeout >/dev/null 2>&1; then
        timeout --signal=TERM --kill-after=5s "${WORKER_TIMEOUT_SEC}s" \
            wine "./grid_compare_test.exe" "$@"
    else
        wine "./grid_compare_test.exe" "$@"
    fi
}

run_logged_compare_worker() {
    local wlog="$1"
    local worker_id="$2"
    local test_desc="$3"
    local start_ts start_human end_ts end_human elapsed rc

    shift 3

    start_ts="$(date +%s)"
    start_human="$(date '+%Y-%m-%d %H:%M:%S')"
    {
        echo "=== worker ${worker_id} START pid=$$ tests=${test_desc} at ${start_human} ==="
    } > "$wlog"

    set +e
    WINEDEBUG=-all run_compare_worker "$@" 2>/dev/null >> "$wlog"
    rc=$?
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        echo "=== worker ${worker_id} TIMEOUT limit=${WORKER_TIMEOUT_SEC}s ===" >> "$wlog"
    fi
    set -e

    end_ts="$(date +%s)"
    end_human="$(date '+%Y-%m-%d %H:%M:%S')"
    elapsed=$((end_ts - start_ts))
    {
        echo "=== worker ${worker_id} END rc=${rc} elapsed=${elapsed}s at ${end_human} ==="
    } >> "$wlog"

    return "$rc"
}

sql_server_target() {
    printf '%s\n' "${VFG_SQL_SERVER:-127.0.0.1,1433}"
}

sql_server_host() {
    local target

    target="$(sql_server_target)"
    printf '%s\n' "${target%%,*}"
}

sql_server_port() {
    local target port

    target="$(sql_server_target)"
    if [[ "$target" == *,* ]]; then
        port="${target#*,}"
    else
        port="1433"
    fi

    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$port"
}

sql_server_reachable() {
    local host port

    host="$(sql_server_host)"
    port="$(sql_server_port)" || return 1

    if command -v timeout >/dev/null 2>&1; then
        timeout 2 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" >/dev/null 2>&1
    else
        bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$host" "$port" >/dev/null 2>&1
    fi
}

parallel_test_is_serial_only() {
    local test_id="$1"

    [ -n "$PARALLEL_UNSAFE_TESTS" ] || return 1
    filter_includes_test "$PARALLEL_UNSAFE_TESTS" "$test_id"
}

selected_tests_require_sql_client() {
    local i=0
    local a
    local only_test=""
    local test_filter=""

    while [ "$i" -lt "${#ARGS[@]}" ]; do
        a="${ARGS[$i]}"
        case "$a" in
            --test)
                if [ $((i + 1)) -lt "${#ARGS[@]}" ]; then
                    only_test="${ARGS[$((i + 1))]}"
                fi
                i=$((i + 2))
                ;;
            --test=*)
                only_test="${a#--test=}"
                i=$((i + 1))
                ;;
            --tests)
                if [ $((i + 1)) -lt "${#ARGS[@]}" ]; then
                    test_filter="${ARGS[$((i + 1))]}"
                fi
                i=$((i + 2))
                ;;
            --tests=*)
                test_filter="${a#--tests=}"
                i=$((i + 1))
                ;;
            *)
                i=$((i + 1))
                ;;
        esac
    done

    if [ -n "$only_test" ]; then
        parallel_test_is_serial_only "$only_test"
        return $?
    fi

    if [ -z "$test_filter" ]; then
        return 1
    fi

    filters_overlap "$SQL_COMPARE_TESTS" "$test_filter"
}

selected_tests_include_parallel_unsafe() {
    local i=0
    local a
    local only_test=""
    local test_filter=""

    while [ "$i" -lt "${#ARGS[@]}" ]; do
        a="${ARGS[$i]}"
        case "$a" in
            --test)
                if [ $((i + 1)) -lt "${#ARGS[@]}" ]; then
                    only_test="${ARGS[$((i + 1))]}"
                fi
                i=$((i + 2))
                ;;
            --test=*)
                only_test="${a#--test=}"
                i=$((i + 1))
                ;;
            --tests)
                if [ $((i + 1)) -lt "${#ARGS[@]}" ]; then
                    test_filter="${ARGS[$((i + 1))]}"
                fi
                i=$((i + 2))
                ;;
            --tests=*)
                test_filter="${a#--tests=}"
                i=$((i + 1))
                ;;
            *)
                i=$((i + 1))
                ;;
        esac
    done

    if [ -n "$only_test" ]; then
        parallel_test_is_serial_only "$only_test"
        return $?
    fi

    if [ -z "$test_filter" ]; then
        return 1
    fi

    filters_overlap "$PARALLEL_UNSAFE_TESTS" "$test_filter"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --headless)
            HEADLESS=1
            shift
            ;;
        --no-headless)
            HEADLESS=0
            shift
            ;;
        --data)
            TESTS_MODE="data"
            TESTS_DIR="${TESTS_DIR_DATA:-./tests_data}"
            shift
            ;;
        --jobs)
            if [ "$#" -lt 2 ]; then
                echo "ERROR: --jobs requires a value"
                exit 1
            fi
            JOBS="$2"
            JOBS_SET=1
            shift 2
            ;;
        --jobs=*)
            JOBS="${1#--jobs=}"
            JOBS_SET=1
            shift
            ;;
        --no-html)
            NO_HTML=1
            ARGS+=("$1")
            shift
            ;;
        --test|--tests)
            if [ "$#" -lt 2 ]; then
                echo "ERROR: $1 requires a value"
                exit 1
            fi
            HAS_FILTER=1
            ARGS+=("$1" "$2")
            shift 2
            ;;
        --test=*|--tests=*)
            HAS_FILTER=1
            ARGS+=("$1")
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ "$JOBS_SET" -eq 0 ]; then
    CPU_COUNT=1
    if command -v nproc >/dev/null 2>&1; then
        CPU_COUNT="$(nproc 2>/dev/null || echo 1)"
    else
        CPU_COUNT="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    fi
    if ! [[ "$CPU_COUNT" =~ ^[0-9]+$ ]] || [ "$CPU_COUNT" -lt 1 ]; then
        CPU_COUNT=1
    fi
    JOBS=$((CPU_COUNT - 2))
    if [ "$JOBS" -lt 1 ]; then
        JOBS=1
    fi
fi

if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || [ "$JOBS" -lt 1 ]; then
    echo "ERROR: --jobs must be a positive integer"
    exit 1
fi

if [ "$HAS_FILTER" -eq 0 ]; then
    if ! DEFAULT_FILTER="$(build_default_filter "$TESTS_DIR")"; then
        if [ "$TESTS_MODE" = "data" ]; then
            DEFAULT_FILTER="${DATA_TEST_FILTER:-66-67}"
        else
            DEFAULT_FILTER="${UI_TEST_FILTER:-1-64}"
        fi
    fi
    ARGS+=(--tests "$DEFAULT_FILTER")
fi

if [ -z "${WINEPREFIX:-}" ]; then
    if [ ! -d "$DEFAULT_NATIVE_WINEPREFIX" ]; then
        echo "ERROR: native MDAC Wine prefix not found: $DEFAULT_NATIVE_WINEPREFIX"
        exit 1
    fi
    export WINEPREFIX="$DEFAULT_NATIVE_WINEPREFIX"
fi
if [ -z "${WINEDLLOVERRIDES:-}" ]; then
    export WINEDLLOVERRIDES="$DEFAULT_NATIVE_WINEDLLOVERRIDES"
fi

if [ "${RUN_COMPARE_UI_XVFB_WRAPPED:-0}" != "1" ]; then
    if [ "$HEADLESS" -eq 1 ]; then
        if ! command -v xvfb-run >/dev/null 2>&1; then
            echo "ERROR: headless mode requested but xvfb-run is not installed"
            exit 1
        fi
        echo "Running under xvfb-run (headless display)"
        export RUN_COMPARE_UI_XVFB_WRAPPED=1
        exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN}" "$SCRIPT_PATH" "${ORIG_ARGS[@]}"
    fi
fi

# ── Preflight ──────────────────────────────────────────────
if [ "$TESTS_MODE" = "data" ]; then
    echo "=== Grid Compare (Data Patterns) ==="
else
    echo "=== Grid Compare: FlexGrid vs VolvoxGrid ==="
fi
echo ""
echo "Using WINEPREFIX: $WINEPREFIX"
echo "Using WINEDLLOVERRIDES: $WINEDLLOVERRIDES"
echo ""

command -v wine >/dev/null 2>&1 || { echo "ERROR: wine not found"; exit 1; }
command -v i686-w64-mingw32-gcc >/dev/null 2>&1 || { echo "ERROR: i686-w64-mingw32-gcc not found"; exit 1; }

# Make Wine runs non-interactive for automation/CI.
WINEDEBUG=-all wine reg add "HKCU\\Software\\Wine\\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f >/dev/null 2>&1 || true
WINEDEBUG=-all wine reg add "HKCU\\Software\\Wine\\WineDbg" /v ShowAssertDialog /t REG_DWORD /d 0 /f >/dev/null 2>&1 || true

if [ ! -f "$REF_OCX" ]; then
    echo "WARNING: $REF_OCX not found — will run with --only-vv"
    ARGS+=("--only-vv")
else
    if [ -z "$REF_PROGID" ]; then
        echo "ERROR: legacy ProgID is empty. Set REF_PROGID or create $REF_PROGID_FILE"
        exit 1
    fi
    ARGS+=("--ref-progid" "$REF_PROGID")
fi

if [ ! -f "$VOLVOX_OCX" ]; then
    echo "ERROR: $VOLVOX_OCX not found — run build_ocx.sh first"
    exit 1
fi

if [ ! -d "$TESTS_DIR" ]; then
    echo "ERROR: test scripts directory not found: $TESTS_DIR"
    exit 1
fi
if [ "$TESTS_MODE" = "data" ]; then
    echo "Using data test scripts: $TESTS_DIR"
else
    echo "Using test scripts: $TESTS_DIR"
fi
if [ "$HAS_FILTER" -eq 0 ]; then
    if [ "$TESTS_MODE" = "data" ]; then
        echo "Default data test filter: $DEFAULT_FILTER"
    else
        echo "Default UI test filter: $DEFAULT_FILTER"
    fi
fi

if [ "$TESTS_MODE" = "ui" ] && selected_tests_require_sql_client; then
    SQL_SERVER_HOST="$(sql_server_host)"
    if ! SQL_SERVER_PORT="$(sql_server_port)"; then
        echo "ERROR: unsupported VFG_SQL_SERVER format: $(sql_server_target)"
        echo "Use host or host,port (for example 127.0.0.1,1433)."
        exit 1
    fi
    echo "[preflight] Verifying MDAC/MSSQL client setup for live SQL compare tests..."
    if ! WINEPREFIX="$WINEPREFIX" WINEDLLOVERRIDES="$WINEDLLOVERRIDES" "$SCRIPT_DIR/setup_mdac28.sh" --verify --sql; then
        echo "ERROR: live SQL compare prerequisites are not ready in $WINEPREFIX"
        echo "Run: $SCRIPT_DIR/setup_mdac28.sh /path/to/MDAC_TYP.EXE"
        exit 1
    fi
    if ! sql_server_reachable; then
        echo "ERROR: SQL compare tests are selected, but SQL Server is not reachable at ${SQL_SERVER_HOST}:${SQL_SERVER_PORT}"
        echo "Start the test server first, for example:"
        echo "  docker run -e \"ACCEPT_EULA=Y\" -e \"MSSQL_SA_PASSWORD=sapassword12#$%\" -e \"MSSQL_PID=Express\" -p 1433:1433 -d mcr.microsoft.com/mssql/server:2017-latest"
        echo "Or skip the live SQL compare cases with: --tests 1-83"
        exit 1
    fi
fi

# ── Build test exe ─────────────────────────────────────────
echo "[1/5] Building grid_compare_test.exe..."
mkdir -p "$TARGET_DIR"
i686-w64-mingw32-gcc -O2 -o "$TARGET_DIR/grid_compare_test.exe" grid_compare_test.c \
    -lole32 -loleaut32 -luuid -lgdi32 -static-libgcc -Wall 2>&1 | head -5
echo "  Done: $TARGET_DIR/grid_compare_test.exe"

# ── Register OCXs ─────────────────────────────────────────
echo "[2/5] Registering OCXs in Wine..."

WINEDEBUG=-all wine regsvr32 /s "$(realpath "$VOLVOX_OCX")" 2>/dev/null || true
echo "  VolvoxGrid: registered"

if [[ ! " ${ARGS[*]:-} " =~ " --only-vv " ]]; then
    WINEDEBUG=-all wine regsvr32 /s "$(realpath "$REF_OCX")" 2>/dev/null || true
    echo "  FlexGrid: registered"
fi

# ── Run comparison ─────────────────────────────────────────
echo "[3/5] Running comparison test..."
mkdir -p "$OUT_DIR"

# Rotate previous similarity mapping
CURR_SIM_FILE="$OUT_DIR/curr_sim.txt"
PREV_SIM_FILE="$OUT_DIR/prev_sim.txt"
if [ -f "$CURR_SIM_FILE" ]; then
    mv -f "$CURR_SIM_FILE" "$PREV_SIM_FILE"
fi

# Symlink VBS test scripts into output dir so the exe can find them
ln -sfn "$(realpath "$TESTS_DIR")" "$OUT_DIR/tests"

# Run in output dir so BMPs land there; capture output for similarity parsing
pushd "$OUT_DIR" > /dev/null
find . -maxdepth 1 -type f \( -name "test_*_lg.bmp" -o -name "test_*_vv.bmp" -o -name "test_*_diff.bmp" -o -name "test_*_lg.png" -o -name "test_*_vv.png" -o -name "test_*_diff.png" -o -name "test_*_cells.diff.txt" -o -name "compare_output.worker*.log" \) -delete
COMPARE_LOG="compare_output.log"
if [ "$JOBS" -le 1 ]; then
    WINEDEBUG=-all run_compare_worker "${ARGS[@]:-}" 2>/dev/null | tee "$COMPARE_LOG" || true
else
    declare -A TEST_SET=()
    TEST_FILTER=""
    ONLY_TEST=""
    BASE_ARGS=()
    TEST_LIST=()
    PARALLEL_TEST_LIST=()
    SERIAL_ONLY_TEST_LIST=()
    CHUNKS=()
    PIDS=()
    WORKER_IDS=()
    WORKER_CHUNKS=()
    WORKER_LOGS=()
    WORKER_FAILS=0
    WORKER_IDX=0

    # Extract filter options and build argument list without test selectors.
    i=0
    while [ "$i" -lt "${#ARGS[@]}" ]; do
        a="${ARGS[$i]}"
        case "$a" in
            --test)
                if [ $((i + 1)) -lt "${#ARGS[@]}" ]; then
                    ONLY_TEST="${ARGS[$((i + 1))]}"
                fi
                i=$((i + 2))
                ;;
            --test=*)
                ONLY_TEST="${a#--test=}"
                i=$((i + 1))
                ;;
            --tests)
                if [ $((i + 1)) -lt "${#ARGS[@]}" ]; then
                    TEST_FILTER="${ARGS[$((i + 1))]}"
                fi
                i=$((i + 2))
                ;;
            --tests=*)
                TEST_FILTER="${a#--tests=}"
                i=$((i + 1))
                ;;
            *)
                BASE_ARGS+=("$a")
                i=$((i + 1))
                ;;
        esac
    done

    if [ -n "$ONLY_TEST" ]; then
        if [[ "$ONLY_TEST" =~ ^[0-9]+$ ]] && [ "$ONLY_TEST" -gt 0 ]; then
            TEST_SET["$ONLY_TEST"]=1
        fi
    else
        IFS=',' read -ra TOKENS <<< "$TEST_FILTER"
        for tok in "${TOKENS[@]}"; do
            tok="${tok//[[:space:]]/}"
            [ -z "$tok" ] && continue
            if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                a="${BASH_REMATCH[1]}"
                b="${BASH_REMATCH[2]}"
                if [ "$a" -le "$b" ]; then
                    for ((t=a; t<=b; t++)); do TEST_SET["$t"]=1; done
                else
                    for ((t=b; t<=a; t++)); do TEST_SET["$t"]=1; done
                fi
            elif [[ "$tok" =~ ^[0-9]+$ ]]; then
                TEST_SET["$tok"]=1
            fi
        done
    fi

    if [ "${#TEST_SET[@]}" -eq 0 ]; then
        echo "  WARN: --jobs requested, but no valid tests parsed; falling back to sequential"
        WINEDEBUG=-all run_compare_worker "${ARGS[@]:-}" 2>/dev/null | tee "$COMPARE_LOG" || true
    else
        mapfile -t TEST_LIST < <(printf "%s\n" "${!TEST_SET[@]}" | sort -n)
        for t in "${TEST_LIST[@]}"; do
            if parallel_test_is_serial_only "$t"; then
                SERIAL_ONLY_TEST_LIST+=("$t")
            else
                PARALLEL_TEST_LIST+=("$t")
            fi
        done

        if [ "${#PARALLEL_TEST_LIST[@]}" -gt 0 ]; then
            PARALLEL_JOBS="$JOBS"
            if [ "$PARALLEL_JOBS" -gt "${#PARALLEL_TEST_LIST[@]}" ]; then
                PARALLEL_JOBS="${#PARALLEL_TEST_LIST[@]}"
            fi

            for ((w=0; w<PARALLEL_JOBS; w++)); do
                CHUNKS[w]=""
            done
            for idx in "${!PARALLEL_TEST_LIST[@]}"; do
                w=$((idx % PARALLEL_JOBS))
                t="${PARALLEL_TEST_LIST[$idx]}"
                if [ -n "${CHUNKS[$w]}" ]; then
                    CHUNKS[$w]="${CHUNKS[$w]},${t}"
                else
                    CHUNKS[$w]="${t}"
                fi
            done

            echo "  Running in parallel with $PARALLEL_JOBS workers"
            for chunk in "${CHUNKS[@]}"; do
                [ -z "$chunk" ] && continue
                WORKER_IDX=$((WORKER_IDX + 1))
                wlog="compare_output.worker${WORKER_IDX}.log"
                WORKER_LOGS+=("$wlog")
                echo "    worker ${WORKER_IDX}: tests ${chunk} (log: ${wlog})"
                (
                    run_logged_compare_worker "$wlog" "$WORKER_IDX" "$chunk" "${BASE_ARGS[@]}" --tests "$chunk"
                ) &
                pid="$!"
                PIDS+=("$pid")
                WORKER_IDS+=("$WORKER_IDX")
                WORKER_CHUNKS+=("$chunk")
                echo "      -> worker ${WORKER_IDX} started (pid=${pid})"
            done

            for idx in "${!PIDS[@]}"; do
                pid="${PIDS[$idx]}"
                wid="${WORKER_IDS[$idx]}"
                chunk="${WORKER_CHUNKS[$idx]}"
                if wait "$pid"; then
                    echo "      <- worker ${wid} done (pid=${pid}, tests=${chunk})"
                else
                    WORKER_FAILS=$((WORKER_FAILS + 1))
                    echo "      <- worker ${wid} FAILED (pid=${pid}, tests=${chunk})"
                fi
            done
        fi

        if [ "${#SERIAL_ONLY_TEST_LIST[@]}" -gt 0 ]; then
            echo "  INFO: running tests $(IFS=,; echo "${SERIAL_ONLY_TEST_LIST[*]}") as isolated workers because tests ${PARALLEL_UNSAFE_TESTS} hang under parallel Wine/ADO compare"
            for test_id in "${SERIAL_ONLY_TEST_LIST[@]}"; do
                WORKER_IDX=$((WORKER_IDX + 1))
                wlog="compare_output.worker${WORKER_IDX}.log"
                WORKER_LOGS+=("$wlog")
                echo "    worker ${WORKER_IDX}: tests ${test_id} (log: ${wlog})"
                if run_logged_compare_worker "$wlog" "$WORKER_IDX" "$test_id" "${BASE_ARGS[@]}" --test "$test_id"; then
                    echo "      <- worker ${WORKER_IDX} done (tests=${test_id})"
                else
                    WORKER_FAILS=$((WORKER_FAILS + 1))
                    echo "      <- worker ${WORKER_IDX} FAILED (tests=${test_id})"
                fi
            done
        fi

        : > "$COMPARE_LOG"
        for wlog in "${WORKER_LOGS[@]}"; do
            [ -f "$wlog" ] || continue
            cat "$wlog" >> "$COMPARE_LOG"
        done
        cat "$COMPARE_LOG"
        if [ "$WORKER_FAILS" -gt 0 ]; then
            echo "  WARN: $WORKER_FAILS worker(s) exited non-zero"
        fi
    fi
fi
popd > /dev/null

echo "  Done."

# ── Convert BMP → PNG ──────────────────────────────────────
echo "[4/5] Converting BMPs to PNG..."
BMP_COUNT=0
if command -v convert >/dev/null 2>&1; then
    BMP_FILES=()
    for bmp in "$OUT_DIR"/test_*.bmp; do
        [ -f "$bmp" ] || continue
        BMP_FILES+=("$bmp")
    done
    BMP_COUNT="${#BMP_FILES[@]}"

    if [ "$BMP_COUNT" -gt 0 ]; then
        CONVERT_JOBS="$JOBS"
        if [ "$CONVERT_JOBS" -gt "$BMP_COUNT" ]; then
            CONVERT_JOBS="$BMP_COUNT"
        fi

        if [ "$CONVERT_JOBS" -le 1 ]; then
            for bmp in "${BMP_FILES[@]}"; do
                png="${bmp%.bmp}.png"
                convert "$bmp" "$png" 2>/dev/null && rm -f "$bmp"
            done
        else
            echo "  Converting in parallel with $CONVERT_JOBS workers"
            set +e
            printf '%s\0' "${BMP_FILES[@]}" | xargs -0 -P "$CONVERT_JOBS" -I '{}' sh -c '
                bmp="$1"
                png="${bmp%.bmp}.png"
                if convert "$bmp" "$png" 2>/dev/null; then
                    rm -f "$bmp"
                    exit 0
                fi
                exit 1
            ' _ '{}'
            CONVERT_RC=$?
            set -e
            if [ "$CONVERT_RC" -ne 0 ]; then
                echo "  WARN: some BMP->PNG conversions failed"
            fi
        fi
    fi
    echo "  Converted $BMP_COUNT images."
else
    echo "  ImageMagick not found — keeping BMPs."
fi

# ── Generate HTML report ───────────────────────────────────
if [ "$NO_HTML" -eq 0 ]; then
    echo "[5/5] Generating HTML report..."
    REPORT="$OUT_DIR/report.html"
    REPORT_GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    REPORT_TESTS_DIR="tests"
    HAS_LG=0
    if [[ ! " ${ARGS[*]:-} " =~ " --only-vv " ]]; then
        HAS_LG=1
    fi

    # Detect image extension
    if ls "$OUT_DIR"/test_*_vv.png >/dev/null 2>&1; then
        EXT="png"
    else
        EXT="bmp"
    fi

    # ── Write HTML ──
    cat > "$REPORT" << 'HEADER'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>FlexGrid vs VolvoxGrid — Comparison Report</title>
<style>
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', -apple-system, sans-serif; background: #0d1117; color: #c9d1d9; margin: 0; padding: 20px 40px; }
h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
.generated-at { color: #8b949e; font-size: 12px; margin: -4px 0 16px; }
.summary { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 16px 24px; margin-bottom: 30px; display: flex; gap: 40px; }
.summary .stat { text-align: center; }
.summary .stat .num { font-size: 32px; font-weight: bold; color: #58a6ff; }
.summary .stat .label { font-size: 12px; color: #8b949e; }

.test { margin: 28px 0; border: 1px solid #30363d; border-radius: 8px; overflow: hidden; background: #161b22; }
.test-header { background: #21262d; padding: 10px 16px; display: flex; align-items: center; gap: 12px; }
.test-header h2 { margin: 0; font-size: 16px; color: #c9d1d9; font-weight: 600; }
.test-header .num { background: #58a6ff; color: #0d1117; border-radius: 4px; padding: 2px 8px; font-size: 13px; font-weight: bold; min-width: 28px; text-align: center; }
.test-header .match { margin-left: auto; font-size: 13px; font-weight: 700; border-radius: 4px; padding: 2px 10px; }
.match-high { background: #238636; color: #fff; }
.match-mid  { background: #9e6a03; color: #fff; }
.match-low  { background: #da3633; color: #fff; }

/* 2x2 grid: script+diff on top, vs+vv on bottom */
.test-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 16px; }
.test-grid .cell { min-width: 0; }
.cell-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
.label-script { color: #8b949e; }
.label-diff   { color: #f85149; }
.label-lg     { color: #f0883e; }
.label-vv     { color: #58a6ff; }

.cell pre { background: #0d1117; border: 1px solid #30363d; border-radius: 6px; padding: 12px; font-size: 12.5px; line-height: 1.6; color: #e6edf3; overflow-x: auto; white-space: pre-wrap; word-break: break-word; font-family: 'Cascadia Code', 'Consolas', 'Courier New', monospace; margin: 0; max-height: 400px; overflow-y: auto; }
.cell img { width: 100%; border: 1px solid #30363d; border-radius: 4px; image-rendering: pixelated; display: block; }
.cell .placeholder { background: #0d1117; border: 1px solid #30363d; border-radius: 4px; padding: 40px; text-align: center; color: #484f58; font-size: 13px; }
.cell-diff { padding: 0 16px 16px; }
.label-celltext { color: #79c0ff; }
</style>
</head>
<body>
<h1>FlexGrid vs VolvoxGrid — Visual Comparison</h1>
HEADER
    echo "<div class=\"generated-at\">Generated: $REPORT_GENERATED_AT</div>" >> "$REPORT"

    # Collect test names
    TESTS=()
    for vv in "$OUT_DIR"/test_*_vv.$EXT; do
        [ -f "$vv" ] || continue
        base=$(basename "$vv" | sed "s/_vv\.$EXT//")
        TESTS+=("$base")
    done
    NUM_TESTS=${#TESTS[@]}
    CELL_DIFF_TESTS=0
    if [ "$HAS_LG" -eq 1 ]; then
        for base in "${TESTS[@]}"; do
            if [ -f "$OUT_DIR/${base}_cells.diff.txt" ]; then
                CELL_DIFF_TESTS=$((CELL_DIFF_TESTS + 1))
            fi
        done
    fi

    # Parse similarity from log
    COMPARE_LOG_FILE="$OUT_DIR/compare_output.log"
    declare -A SIM_MAP
    AVG_SIM=""
    if [ -f "$COMPARE_LOG_FILE" ]; then
        cur_num=""
        while IFS= read -r line; do
            line="${line%$'\r'}"
            # Lines like: [02] colors / Similarity: 87.8%
            if [[ "$line" =~ ^\[([0-9]+)\][[:space:]]+(.+) ]]; then
                cur_num="${BASH_REMATCH[1]}"
                cur_name="${BASH_REMATCH[2]}"
            elif [[ -n "$cur_num" && "$line" =~ ^[[:space:]]*Similarity:[[:space:]]*([0-9.]+)% ]]; then
                SIM_MAP["$cur_num"]="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ [Aa][Vv][Gg][[:space:]]+similarity:[[:space:]]*([0-9.]+)% ]]; then
                AVG_SIM="${BASH_REMATCH[1]}"
            fi
        done < "$COMPARE_LOG_FILE"
    fi

    set +u
    if [ "${#SIM_MAP[@]}" -gt 0 ]; then
        rm -f "$CURR_SIM_FILE"
        for key in $(printf '%s\n' "${!SIM_MAP[@]}" | sort -n); do
            echo "$key ${SIM_MAP[$key]}" >> "$CURR_SIM_FILE"
        done
    fi

    DIFF_SUMMARY_HTML=""
    if [ -f "$PREV_SIM_FILE" ] && [ "${#SIM_MAP[@]}" -gt 0 ]; then
        declare -A PREV_SIM_MAP
        while read -r p_num p_sim; do
            if [ -n "$p_num" ]; then
                PREV_SIM_MAP["$p_num"]="$p_sim"
            fi
        done < "$PREV_SIM_FILE"
        
        DIFF_ITEMS=""
        for key in $(printf '%s\n' "${!SIM_MAP[@]}" | sort -n); do
            c_sim="${SIM_MAP[$key]}"
            p_sim="${PREV_SIM_MAP[$key]:-}"
            if [ -n "$p_sim" ] && [ "$c_sim" != "$p_sim" ]; then
                if awk "BEGIN {exit !($c_sim > $p_sim)}"; then
                    color="#238636" # green
                    arrow="&uarr;"
                else
                    color="#da3633" # red
                    arrow="&darr;"
                fi
                DIFF_ITEMS+="<li>Test <b>$key</b>: $p_sim% &rarr; <span style=\"color: $color; font-weight: bold;\">$c_sim% $arrow</span></li>"
            fi
        done
        if [ -n "$DIFF_ITEMS" ]; then
            DIFF_SUMMARY_HTML="<div class=\"diff-summary\" style=\"background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 16px 24px; margin-bottom: 30px;\"><h3 style=\"margin-top: 0; color: #c9d1d9; font-size: 16px;\">Similarity Changes Since Last Run</h3><ul style=\"margin: 0; padding-left: 20px; color: #8b949e; font-size: 14px;\">$DIFF_ITEMS</ul></div>"
        fi
    fi

    if [ -n "$DIFF_SUMMARY_HTML" ]; then
        echo "$DIFF_SUMMARY_HTML" >> "$REPORT"
    fi

    # Summary
    {
        echo "<div class=\"summary\">"
        echo "  <div class=\"stat\"><div class=\"num\">$NUM_TESTS</div><div class=\"label\">Tests</div></div>"
        if [ "$HAS_LG" -eq 1 ]; then
            echo "  <div class=\"stat\"><div class=\"num\">2</div><div class=\"label\">Controls</div></div>"
            echo "  <div class=\"stat\"><div class=\"num\">$CELL_DIFF_TESTS</div><div class=\"label\">Cell Diff Tests</div></div>"
        fi
        if [ -n "$AVG_SIM" ]; then
            echo "  <div class=\"stat\"><div class=\"num\">${AVG_SIM}%</div><div class=\"label\">Avg Similarity</div></div>"
        fi
        echo "</div>"
    } >> "$REPORT"

    for base in "${TESTS[@]}"; do
        num="${base#test_}"
        num="${num%%_*}"
        name="${base#test_${num}_}"

        # Load VBScript from file
        vbs_file="$REPORT_TESTS_DIR/${num}_${name}.vbs"
        if [ -f "$vbs_file" ]; then
            # HTML-escape <, >, & for safe embedding in <pre>
            vbs_content=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$vbs_file")
        else
            vbs_content="' (no script file: ${num}_${name}.vbs)"
        fi

        cell_diff_file="$OUT_DIR/${base}_cells.diff.txt"
        cell_diff_content=""
        if [ -f "$cell_diff_file" ]; then
            cell_diff_content=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$cell_diff_file")
        fi

        # Get similarity for this test
        sim_val="${SIM_MAP[$num]:-}"
        sim_badge=""
        if [ -n "$sim_val" ]; then
            sim_int=${sim_val%.*}
            if [ "$sim_int" -ge 90 ]; then
                sim_class="match-high"
            elif [ "$sim_int" -ge 75 ]; then
                sim_class="match-mid"
            else
                sim_class="match-low"
            fi
            sim_badge="<span class=\"match $sim_class\">${sim_val}%</span>"
        fi

        {
            echo "<div class=\"test\">"
            echo "  <div class=\"test-header\">"
            echo "    <span class=\"num\">$num</span>"
            echo "    <h2>$name</h2>"
            echo "    $sim_badge"
            echo "  </div>"
            echo "  <div class=\"test-grid\">"

            # Top-left: VBScript
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-script\">VBScript</div>"
            echo "      <pre>$vbs_content</pre>"
            echo "    </div>"

            # Top-right: Diff
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-diff\">Diff</div>"
            if [ "$HAS_LG" -eq 1 ] && [ -f "$OUT_DIR/${base}_diff.$EXT" ]; then
                echo "      <img src=\"${base}_diff.$EXT\">"
            else
                echo "      <div class=\"placeholder\">No diff (single control mode)</div>"
            fi
            echo "    </div>"

            # Bottom-left: FlexGrid
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-lg\">FlexGrid</div>"
            if [ "$HAS_LG" -eq 1 ] && [ -f "$OUT_DIR/${base}_lg.$EXT" ]; then
                echo "      <img src=\"${base}_lg.$EXT\">"
            else
                echo "      <div class=\"placeholder\">Not registered</div>"
            fi
            echo "    </div>"

            # Bottom-right: VolvoxGrid
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-vv\">VolvoxGrid</div>"
            echo "      <img src=\"${base}_vv.$EXT\">"
            echo "    </div>"

            echo "  </div>"

            echo "  <div class=\"cell cell-diff\">"
            echo "    <div class=\"cell-label label-celltext\">Cell Text Diff</div>"
            if [ "$HAS_LG" -eq 1 ] && [ -n "$cell_diff_content" ]; then
                echo "    <pre>$cell_diff_content</pre>"
            elif [ "$HAS_LG" -eq 1 ]; then
                echo "    <div class=\"placeholder\">No cell text differences</div>"
            else
                echo "    <div class=\"placeholder\">No reference control</div>"
            fi
            echo "  </div>"
            echo "</div>"
        } >> "$REPORT"
    done

    echo "</body></html>" >> "$REPORT"
    echo "  Report: $OUT_DIR/report.html"
else
    echo "[5/5] Skipping HTML report (--no-html)."
fi

# ── Summary ────────────────────────────────────────────────
CELL_DIFF_CASES=()
for cell_diff_path in "$OUT_DIR"/test_*_cells.diff.txt; do
    [ -f "$cell_diff_path" ] || continue
    cell_diff_base="$(basename "$cell_diff_path")"
    cell_diff_num="${cell_diff_base#test_}"
    cell_diff_num="${cell_diff_num%%_*}"
    cell_diff_name="${cell_diff_base#test_${cell_diff_num}_}"
    cell_diff_name="${cell_diff_name%_cells.diff.txt}"
    CELL_DIFF_CASES+=("[$cell_diff_num] $cell_diff_name")
done

echo ""
echo "════════════════════════════════════════════════"
echo "  Output: $OUT_DIR/"
ls "$OUT_DIR"/*.${EXT:-png} 2>/dev/null | wc -l | xargs -I{} echo "  Images: {} files"
[ -f "$OUT_DIR/report.html" ] && echo "  Report: $OUT_DIR/report.html"
if [ "${#CELL_DIFF_CASES[@]}" -gt 0 ]; then
    echo "  Cell Text Diff Cases:"
    for cell_diff_case in "${CELL_DIFF_CASES[@]}"; do
        echo "    $cell_diff_case"
    done
else
    echo "  Cell Text Diff Cases: none"
fi
echo "════════════════════════════════════════════════"
