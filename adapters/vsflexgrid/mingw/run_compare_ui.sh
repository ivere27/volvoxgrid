#!/bin/bash
# run_compare_ui.sh — Build & run grid comparison: FlexGrid vs VolvoxGrid
#
# Registers both OCXs in Wine, runs grid_compare_test.exe, converts
# output BMPs to PNG, and generates a side-by-side HTML report.
#
# Usage:
#   ./run_compare_ui.sh [--only-vv] [--no-diff] [--no-html] [--test N] [--tests LIST]

set -euo pipefail
cd "$(dirname "$0")"

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
ARGS=()
NO_HTML=0
HAS_FILTER=0
DEFAULT_FILTER=""

for arg in "$@"; do
    case "$arg" in
        --no-html) NO_HTML=1 ;;
        --test|--tests|--test=*|--tests=*) HAS_FILTER=1; ARGS+=("$arg") ;;
        *) ARGS+=("$arg") ;;
    esac
done

if [ "$HAS_FILTER" -eq 0 ]; then
    DEFAULT_FILTER="${UI_TEST_FILTER:-1-64}"
    ARGS+=(--tests "$DEFAULT_FILTER")
fi

# ── Preflight ──────────────────────────────────────────────
echo "=== Grid Compare: FlexGrid vs VolvoxGrid ==="
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
echo "Using test scripts: $TESTS_DIR"
if [ "$HAS_FILTER" -eq 0 ]; then
    echo "Default UI test filter: $DEFAULT_FILTER"
fi

# ── Build test exe ─────────────────────────────────────────
echo "[1/5] Building grid_compare_test.exe..."
mkdir -p "$TARGET_DIR"
i686-w64-mingw32-gcc -O2 -o "$TARGET_DIR/grid_compare_test.exe" grid_compare_test.c \
    -lole32 -loleaut32 -luuid -lgdi32 -static-libgcc -Wall 2>&1 | head -5
echo "  Done: $TARGET_DIR/grid_compare_test.exe"

# ── Register OCXs ─────────────────────────────────────────
echo "[2/5] Registering OCXs in Wine..."

WINEDEBUG=-all wine regsvr32 "$(realpath "$VOLVOX_OCX")" 2>/dev/null || true
echo "  VolvoxGrid: registered"

if [[ ! " ${ARGS[*]:-} " =~ " --only-vv " ]]; then
    WINEDEBUG=-all wine regsvr32 "$(realpath "$REF_OCX")" 2>/dev/null || true
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
WINEDEBUG=-all wine "./grid_compare_test.exe" "${ARGS[@]:-}" 2>/dev/null | tee "$COMPARE_LOG" || true
popd > /dev/null

echo "  Done."

# ── Convert BMP → PNG ──────────────────────────────────────
echo "[4/5] Converting BMPs to PNG..."
BMP_COUNT=0
if command -v convert >/dev/null 2>&1; then
    for bmp in "$OUT_DIR"/test_*.bmp; do
        [ -f "$bmp" ] || continue
        png="${bmp%.bmp}.png"
        convert "$bmp" "$png" 2>/dev/null && rm -f "$bmp"
        BMP_COUNT=$((BMP_COUNT + 1))
    done
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

        # Load VBScript from file
        vbs_file="$REPORT_TESTS_DIR/${num}_${name}.vbs"
        if [ -f "$vbs_file" ]; then
            # HTML-escape <, >, & for safe embedding in <pre>
            vbs_content=$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$vbs_file")
        else
            vbs_content="' (no script file: ${num}_${name}.vbs)"
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
