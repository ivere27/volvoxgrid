#!/bin/bash
# run_compare_ux.sh — Build & run interactive UI+UX comparison
#
# Registers both OCXs in Wine, runs grid_compare_ux_test.exe, converts
# output BMPs to PNG, and generates a side-by-side HTML report.
#
# Usage:
#   ./run_compare_ux.sh [--headless] [--no-headless] [--jobs N] [--only-vv] [--no-diff] [--no-html] [--test N] [--tests LIST]
#
# UI+UX test source set:
#   - defaults to ./tests_uiux
#   - override with env TESTS_DIR_UIUX=./my_uiux_tests
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
TARGET_DIR="../../../target/ocx/compare_ux"
OUT_DIR="$TARGET_DIR"
TESTS_DIR="${TESTS_DIR_UIUX:-./tests_uiux}"
ARGS=()
NO_HTML=0
HAS_FILTER=0
DEFAULT_FILTER=""
HEADLESS=1
XVFB_SCREEN="${XVFB_SCREEN:-1920x1080x24}"
JOBS=0
JOBS_SET=0

ORIG_ARGS=("$@")
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
    DEFAULT_FILTER="${UIUX_TEST_FILTER:-1-65}"
    ARGS+=(--tests "$DEFAULT_FILTER")
fi

# Re-exec under Xvfb for headless Wine runs when requested.
if [ "${RUN_COMPARE_UX_XVFB_WRAPPED:-0}" != "1" ]; then
    if [ "$HEADLESS" -eq 1 ]; then
        if ! command -v xvfb-run >/dev/null 2>&1; then
            echo "ERROR: headless mode requested but xvfb-run is not installed"
            exit 1
        fi
        echo "Running under xvfb-run (headless display)"
        export RUN_COMPARE_UX_XVFB_WRAPPED=1
        exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN}" "$SCRIPT_PATH" "${ORIG_ARGS[@]}"
    fi
fi

# ── Preflight ──────────────────────────────────────────────
echo "=== Grid Compare (UI+UX): FlexGrid vs VolvoxGrid ==="
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
        echo "ERROR: reference ProgID is empty. Set REF_PROGID or create $REF_PROGID_FILE"
        exit 1
    fi
    ARGS+=("--ref-progid" "$REF_PROGID")
fi

if [ ! -f "$VOLVOX_OCX" ]; then
    echo "ERROR: $VOLVOX_OCX not found — run build_ocx.sh first"
    exit 1
fi

if [ ! -d "$TESTS_DIR" ]; then
    echo "ERROR: UI+UX tests directory not found: $TESTS_DIR"
    echo "       Expected split scripts under adapters/vsflexgrid/mingw/tests_uiux/"
    exit 1
fi
echo "Using UI+UX test scripts: $TESTS_DIR"
if [ "$HAS_FILTER" -eq 0 ]; then
    echo "Default UI+UX test filter: $DEFAULT_FILTER"
fi

# ── Build test exe ─────────────────────────────────────────
echo "[1/5] Building grid_compare_ux_test.exe..."
mkdir -p "$TARGET_DIR"
i686-w64-mingw32-gcc -O2 -o "$TARGET_DIR/grid_compare_ux_test.exe" grid_compare_ux_test.c \
    -lole32 -loleaut32 -luuid -lgdi32 -static-libgcc -Wall 2>&1 | head -5
echo "  Done: $TARGET_DIR/grid_compare_ux_test.exe"

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
COMPARE_LOG="compare_output.log"
if [ "$JOBS" -le 1 ]; then
    WINEDEBUG=-all wine "./grid_compare_ux_test.exe" "${ARGS[@]:-}" 2>/dev/null | tee "$COMPARE_LOG" || true
else
    declare -A TEST_SET=()
    TEST_FILTER=""
    ONLY_TEST=""
    BASE_ARGS=()
    TEST_LIST=()
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
        WINEDEBUG=-all wine "./grid_compare_ux_test.exe" "${ARGS[@]:-}" 2>/dev/null | tee "$COMPARE_LOG" || true
    else
        mapfile -t TEST_LIST < <(printf "%s\n" "${!TEST_SET[@]}" | sort -n)
        if [ "$JOBS" -gt "${#TEST_LIST[@]}" ]; then
            JOBS="${#TEST_LIST[@]}"
        fi

        for ((w=0; w<JOBS; w++)); do
            CHUNKS[w]=""
        done
        for idx in "${!TEST_LIST[@]}"; do
            w=$((idx % JOBS))
            t="${TEST_LIST[$idx]}"
            if [ -n "${CHUNKS[$w]}" ]; then
                CHUNKS[$w]="${CHUNKS[$w]},${t}"
            else
                CHUNKS[$w]="${t}"
            fi
        done

        echo "  Running in parallel with $JOBS workers"
        for chunk in "${CHUNKS[@]}"; do
            [ -z "$chunk" ] && continue
            WORKER_IDX=$((WORKER_IDX + 1))
            wlog="compare_output.worker${WORKER_IDX}.log"
            WORKER_LOGS+=("$wlog")
            echo "    worker ${WORKER_IDX}: tests ${chunk} (log: ${wlog})"
            (
                start_ts="$(date +%s)"
                start_human="$(date '+%Y-%m-%d %H:%M:%S')"
                {
                    echo "=== worker ${WORKER_IDX} START pid=$$ tests=${chunk} at ${start_human} ==="
                } > "$wlog"
                set +e
                WINEDEBUG=-all wine "./grid_compare_ux_test.exe" "${BASE_ARGS[@]}" --tests "$chunk" \
                    2>/dev/null >> "$wlog"
                rc=$?
                set -e
                end_ts="$(date +%s)"
                end_human="$(date '+%Y-%m-%d %H:%M:%S')"
                elapsed=$((end_ts - start_ts))
                {
                    echo "=== worker ${WORKER_IDX} END rc=${rc} elapsed=${elapsed}s at ${end_human} ==="
                } >> "$wlog"
                exit "$rc"
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
echo "[4/5] Converting BMPs to PNG (keeping BMPs)..."
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
                convert "$bmp" "$png" 2>/dev/null
            done
        else
            echo "  Converting in parallel with $CONVERT_JOBS workers"
            set +e
            printf '%s\0' "${BMP_FILES[@]}" | xargs -0 -P "$CONVERT_JOBS" -I '{}' sh -c '
                bmp="$1"
                png="${bmp%.bmp}.png"
                if convert "$bmp" "$png" 2>/dev/null; then
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
    echo "  Converted $BMP_COUNT images and kept the source BMPs."
else
    echo "  ImageMagick not found — keeping BMPs."
fi

# ── Generate HTML report ───────────────────────────────────
if [ "$NO_HTML" -eq 0 ]; then
    echo "[5/5] Generating HTML report..."
    REPORT="$OUT_DIR/report.html"
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
<title>FlexGrid vs VolvoxGrid — UI+UX Comparison Report</title>
<style>
* { box-sizing: border-box; }
body { font-family: 'Segoe UI', -apple-system, sans-serif; background: #0d1117; color: #c9d1d9; margin: 0; padding: 20px 40px; }
h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 12px; }
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
.script-meta { padding: 0 16px 14px 16px; font-size: 12px; color: #8b949e; }
.script-meta a { color: #58a6ff; text-decoration: none; }
.script-meta a:hover { text-decoration: underline; }
</style>
</head>
<body>
<h1>FlexGrid vs VolvoxGrid — UI+UX Visual Comparison</h1>
HEADER

    # Collect test names
    TESTS=()
    for vv in "$OUT_DIR"/test_*_vv.$EXT; do
        [ -f "$vv" ] || continue
        base=$(basename "$vv" | sed "s/_vv\.$EXT//")
        TESTS+=("$base")
    done
    NUM_TESTS=${#TESTS[@]}

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

        # Prefer the exact executed script dumped by grid_compare_ux_test.exe
        gen_vbs_file="$OUT_DIR/${base}_script.vbs"
        src_vbs_file="$TESTS_DIR/${num}_${name}.vbs"
        vbs_file="$gen_vbs_file"
        vbs_label="VBScript (executed)"
        vbs_href="${base}_script.vbs"
        script_meta="Script file: <code>${base}_script.vbs</code>"

        if [ ! -f "$vbs_file" ]; then
            vbs_file="$src_vbs_file"
            vbs_label="VBScript (source)"
            vbs_href="tests/${num}_${name}.vbs"
            script_meta="Script file: <code>${src_vbs_file}</code>"
        fi

        if [ -f "$vbs_file" ]; then
            # HTML-escape <, >, & for safe embedding in <pre>
            vbs_content=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$vbs_file")
            script_meta="$script_meta &nbsp; <a href=\"$vbs_href\" target=\"_blank\" rel=\"noopener\">open</a>"
        else
            vbs_content="' (no script file: ${num}_${name}.vbs)"
            script_meta="Script file: (missing)"
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
            echo "      <div class=\"cell-label label-script\">$vbs_label</div>"
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
            echo "  <div class=\"script-meta\">$script_meta</div>"
            echo "</div>"
        } >> "$REPORT"
    done

    echo "</body></html>" >> "$REPORT"
    echo "  Report: $OUT_DIR/report.html"
else
    echo "[5/5] Skipping HTML report (--no-html)."
fi

# ── Summary ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  Output: $OUT_DIR/"
ls "$OUT_DIR"/*.${EXT:-png} 2>/dev/null | wc -l | xargs -I{} echo "  Images: {} files"
[ -f "$OUT_DIR/report.html" ] && echo "  Report: $OUT_DIR/report.html"
echo "════════════════════════════════════════════════"
