#!/bin/bash
# run_compare_ui.sh — Capture per-case screenshots of SfDataGrid vs VolvoxGrid,
# generate pixel diffs and HTML comparison report.
#
# Uses headless flutter test (no Xvfb required).
#
# Usage:
#   ./run_compare_ui.sh [--only-vv] [--no-html] [--no-diff] [--skip-build] [--skip-pub-get] [--fast] [--test N] [--tests LIST]
#
# Speed tuning via env (defaults are fast but configurable):
#   VOLVOXGRID_COMPARE_FFI_PUMP_SLEEP_MS
#   VOLVOXGRID_COMPARE_FFI_INIT_CYCLES
#   VOLVOXGRID_COMPARE_FFI_STYLE_CYCLES
#   VOLVOXGRID_COMPARE_FFI_HOOK_CYCLES
#   VOLVOXGRID_COMPARE_FFI_CLEANUP_CYCLES
#   VOLVOXGRID_COMPARE_FFI_FINAL_CYCLES

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ADAPTER_DIR="$SCRIPT_DIR"
OUT_DIR="$ROOT_DIR/target/sfdatagrid/compare"
COMPARE_LOG="$OUT_DIR/compare_output.log"
PUBSPEC_OVERRIDES_FILE="$ADAPTER_DIR/pubspec_overrides.yaml"

NO_HTML=0
NO_DIFF=0
ONLY_VV=0
SKIP_BUILD=0
SKIP_PUB_GET=0
FAST_MODE=0
TEST_FILTER=""

FFI_PUMP_SLEEP_MS="${VOLVOXGRID_COMPARE_FFI_PUMP_SLEEP_MS:-8}"
FFI_INIT_CYCLES="${VOLVOXGRID_COMPARE_FFI_INIT_CYCLES:-14}"
FFI_STYLE_CYCLES="${VOLVOXGRID_COMPARE_FFI_STYLE_CYCLES:-10}"
FFI_HOOK_CYCLES="${VOLVOXGRID_COMPARE_FFI_HOOK_CYCLES:-8}"
FFI_CLEANUP_CYCLES="${VOLVOXGRID_COMPARE_FFI_CLEANUP_CYCLES:-6}"
FFI_FINAL_CYCLES="${VOLVOXGRID_COMPARE_FFI_FINAL_CYCLES:-4}"
TEMP_OVERRIDES_CREATED=0
CASES_DEST=""
GENERATED_TEST=""

cleanup_generated() {
    if [ -n "$CASES_DEST" ]; then
        rm -rf "$CASES_DEST"
    fi
    if [ -n "$GENERATED_TEST" ]; then
        rm -f "$GENERATED_TEST"
    fi
    if [ "$TEMP_OVERRIDES_CREATED" -eq 1 ]; then
        rm -f "$PUBSPEC_OVERRIDES_FILE"
    fi
}
trap cleanup_generated EXIT

ensure_local_pubspec_override() {
    if [ -f "$PUBSPEC_OVERRIDES_FILE" ]; then
        return
    fi
    if [ ! -f "$ROOT_DIR/flutter/pubspec.yaml" ]; then
        return
    fi
    cat > "$PUBSPEC_OVERRIDES_FILE" << 'EOF'
dependency_overrides:
  volvoxgrid:
    path: ../../flutter
EOF
    TEMP_OVERRIDES_CREATED=1
    echo "  Added temporary local override (volvoxgrid -> ../../flutter)."
}

parse_non_negative_int() {
    local value="$1"
    local fallback="$2"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo "$fallback"
    fi
}

for arg in "$@"; do
    case "$arg" in
        --no-html) NO_HTML=1 ;;
        --no-diff) NO_DIFF=1 ;;
        --only-vv) ONLY_VV=1 ;;
        --skip-build) SKIP_BUILD=1 ;;
        --skip-pub-get) SKIP_PUB_GET=1 ;;
        --fast) FAST_MODE=1 ;;
        --test=*) TEST_FILTER="${arg#--test=}" ;;
        --tests=*) TEST_FILTER="${arg#--tests=}" ;;
        --ffi-pump-sleep-ms=*) FFI_PUMP_SLEEP_MS="${arg#--ffi-pump-sleep-ms=}" ;;
        --ffi-init-cycles=*) FFI_INIT_CYCLES="${arg#--ffi-init-cycles=}" ;;
        --ffi-style-cycles=*) FFI_STYLE_CYCLES="${arg#--ffi-style-cycles=}" ;;
        --ffi-hook-cycles=*) FFI_HOOK_CYCLES="${arg#--ffi-hook-cycles=}" ;;
        --ffi-cleanup-cycles=*) FFI_CLEANUP_CYCLES="${arg#--ffi-cleanup-cycles=}" ;;
        --ffi-final-cycles=*) FFI_FINAL_CYCLES="${arg#--ffi-final-cycles=}" ;;
        --test) ;;
        --tests) ;;
    esac
done

# Handle --test N / --tests N,M forms
prev=""
for arg in "$@"; do
    if [ "$prev" = "--test" ] || [ "$prev" = "--tests" ]; then
        TEST_FILTER="$arg"
    fi
    prev="$arg"
done

if [ "$FAST_MODE" -eq 1 ]; then
    # Quick smoke profile (faster, but may reduce visual-stability on heavy cases).
    FFI_PUMP_SLEEP_MS=6
    FFI_INIT_CYCLES=10
    FFI_STYLE_CYCLES=8
    FFI_HOOK_CYCLES=6
    FFI_CLEANUP_CYCLES=4
    FFI_FINAL_CYCLES=3
fi

FFI_PUMP_SLEEP_MS="$(parse_non_negative_int "$FFI_PUMP_SLEEP_MS" 8)"
FFI_INIT_CYCLES="$(parse_non_negative_int "$FFI_INIT_CYCLES" 14)"
FFI_STYLE_CYCLES="$(parse_non_negative_int "$FFI_STYLE_CYCLES" 10)"
FFI_HOOK_CYCLES="$(parse_non_negative_int "$FFI_HOOK_CYCLES" 8)"
FFI_CLEANUP_CYCLES="$(parse_non_negative_int "$FFI_CLEANUP_CYCLES" 6)"
FFI_FINAL_CYCLES="$(parse_non_negative_int "$FFI_FINAL_CYCLES" 4)"

mkdir -p "$OUT_DIR"
# Rotate previous similarity mapping
CURR_SIM_FILE="$OUT_DIR/curr_sim.txt"
PREV_SIM_FILE="$OUT_DIR/prev_sim.txt"
if [ -f "$CURR_SIM_FILE" ]; then
    mv -f "$CURR_SIM_FILE" "$PREV_SIM_FILE"
fi

# Remove stale capture artifacts so partial runs remain accurate and fast.
rm -f "$OUT_DIR"/test_*_ref.png "$OUT_DIR"/test_*_vv.png "$OUT_DIR"/test_*_diff.png \
      "$OUT_DIR"/scripts.json "$OUT_DIR"/report.html "$COMPARE_LOG"

# ── Preflight ──────────────────────────────────────────────────────
echo "=== SfDataGrid vs VolvoxGrid — Capture Compare ==="
echo ""

command -v flutter >/dev/null 2>&1 || { echo "ERROR: flutter not found"; exit 1; }
command -v dart >/dev/null 2>&1 || { echo "ERROR: dart not found"; exit 1; }

HAS_IMAGEMAGICK=0
if [ "$NO_DIFF" -eq 0 ] && [ "$ONLY_VV" -eq 0 ]; then
    if command -v compare >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
        HAS_IMAGEMAGICK=1
    else
        echo "WARNING: ImageMagick (compare/identify) not found — skipping diff images"
    fi
fi

# ── Locate / Build native library ──────────────────────────────────
NATIVE_LIB_DIR="$ROOT_DIR/target/release"
NATIVE_LIB_PATH="$NATIVE_LIB_DIR/libvolvoxgrid_plugin.so"
if [ "$SKIP_BUILD" -eq 0 ]; then
    NEED_REBUILD=0
    REBUILD_REASON=""
    if [ ! -f "$NATIVE_LIB_PATH" ]; then
        NEED_REBUILD=1
        REBUILD_REASON="(library missing)"
    else
        BUILD_INPUTS=(
            "$ROOT_DIR/plugin/src"
            "$ROOT_DIR/engine/src"
            "$ROOT_DIR/proto/volvoxgrid.proto"
            "$ROOT_DIR/plugin/Cargo.toml"
            "$ROOT_DIR/engine/Cargo.toml"
        )
        for input in "${BUILD_INPUTS[@]}"; do
            if [ -d "$input" ]; then
                if find "$input" -type f -newer "$NATIVE_LIB_PATH" -print -quit | grep -q .; then
                    NEED_REBUILD=1
                    REBUILD_REASON="(source newer than library: $input)"
                    break
                fi
            elif [ -f "$input" ] && [ "$input" -nt "$NATIVE_LIB_PATH" ]; then
                NEED_REBUILD=1
                REBUILD_REASON="(source newer than library: $input)"
                break
            fi
        done
    fi

    if [ "$NEED_REBUILD" -eq 1 ]; then
        echo "[1/6] Building native library..."
        if [ -n "$REBUILD_REASON" ]; then
            echo "  $REBUILD_REASON"
        fi
        cargo build --manifest-path "$ROOT_DIR/plugin/Cargo.toml" --release 2>&1 | tail -3
    else
        echo "[1/6] Native library already built."
    fi
else
    echo "[1/6] Skipping native library build (--skip-build)"
fi

if [ ! -f "$NATIVE_LIB_PATH" ]; then
    echo "ERROR: libvolvoxgrid_plugin.so not found in $NATIVE_LIB_DIR"
    exit 1
fi

# ── Resolve dependencies ───────────────────────────────────────────
echo "[2/6] Resolving adapter dependencies..."
ensure_local_pubspec_override
if [ "$SKIP_PUB_GET" -eq 1 ]; then
    echo "  Skipped (--skip-pub-get)."
else
    SHOULD_PUB_GET=0
    if [ ! -f "$ADAPTER_DIR/.dart_tool/package_config.json" ] || [ ! -f "$ADAPTER_DIR/pubspec.lock" ] || [ "$ADAPTER_DIR/pubspec.yaml" -nt "$ADAPTER_DIR/pubspec.lock" ]; then
        SHOULD_PUB_GET=1
    fi

    if [ "$SHOULD_PUB_GET" -eq 1 ]; then
        if ! (
          cd "$ADAPTER_DIR"
          flutter pub get >/dev/null 2>&1
        ); then
          echo "ERROR: flutter pub get failed in $ADAPTER_DIR"
          echo "  Try: (cd $ADAPTER_DIR && flutter pub get)"
          exit 1
        fi
        echo "  Done."
    else
        echo "  Skipped (pubspec.lock is up to date)."
    fi
fi

# ── Generate Test Runner ───────────────────────────────────────────
echo "[3/6] Generating test runner..."
CASES_DEST="$ADAPTER_DIR/test/sfdatagrid_cases"
GENERATED_TEST="$ADAPTER_DIR/test/sfdatagrid_compare_test.dart"
SCRIPTS_JSON="$OUT_DIR/scripts.json"

mkdir -p "$CASES_DEST/cases"
cp "$SCRIPT_DIR/test/common.dart" "$CASES_DEST/"
cp "$SCRIPT_DIR/test/cases/"*.dart "$CASES_DEST/cases/"

dart "$SCRIPT_DIR/tool/generate_runner.dart" "$CASES_DEST/cases" "$GENERATED_TEST" "$SCRIPTS_JSON"
echo "  Done."

# ── Run flutter test (headless) ────────────────────────────────────
echo "[4/6] Running capture test..."
echo "  FFI speed config: sleep=${FFI_PUMP_SLEEP_MS}ms init/style/hook/cleanup/final=${FFI_INIT_CYCLES}/${FFI_STYLE_CYCLES}/${FFI_HOOK_CYCLES}/${FFI_CLEANUP_CYCLES}/${FFI_FINAL_CYCLES}"

pushd "$ADAPTER_DIR" >/dev/null
set +e
LD_LIBRARY_PATH="$NATIVE_LIB_DIR" \
  CAPTURE_COMPARE_OUT="$OUT_DIR" \
  TEST_FILTER="$TEST_FILTER" \
  FFI_PUMP_SLEEP_MS="$FFI_PUMP_SLEEP_MS" \
  FFI_INIT_CYCLES="$FFI_INIT_CYCLES" \
  FFI_STYLE_CYCLES="$FFI_STYLE_CYCLES" \
  FFI_HOOK_CYCLES="$FFI_HOOK_CYCLES" \
  FFI_CLEANUP_CYCLES="$FFI_CLEANUP_CYCLES" \
  FFI_FINAL_CYCLES="$FFI_FINAL_CYCLES" \
  flutter test test/sfdatagrid_compare_test.dart \
  2>&1 | tee "$COMPARE_LOG"
TEST_EXIT=${PIPESTATUS[0]}
set -e
popd >/dev/null

if [ "$TEST_EXIT" -ne 0 ]; then
    echo "  WARNING: flutter test exited with code $TEST_EXIT"
else
    echo "  Done."
fi

# ── Generate diff images ───────────────────────────────────────────
if [ "$NO_DIFF" -eq 1 ] || [ "$ONLY_VV" -eq 1 ]; then
    echo "[5/6] Skipping diff images (--no-diff or --only-vv)."
else
    echo "[5/6] Generating diff images..."
fi

DIFF_COUNT=0
AVG_SIM=""
declare -A DIFF_SIM_MAP
DIFF_SIM_COUNT=0
if [ "$HAS_IMAGEMAGICK" -eq 1 ]; then
    for ref_png in "$OUT_DIR"/test_*_ref.png; do
        [ -f "$ref_png" ] || continue
        base=$(basename "$ref_png" | sed 's/_ref\.png//')
        vv_png="$OUT_DIR/${base}_vv.png"
        diff_png="$OUT_DIR/${base}_diff.png"

        if [ ! -f "$vv_png" ]; then
            continue
        fi

        DIFF_PIXELS=$(compare -metric AE -fuzz 5% "$ref_png" "$vv_png" "$diff_png" 2>&1 || true)
        DIFF_COUNT=$((DIFF_COUNT + 1))

        num="${base#test_}"
        num="${num%%_*}"
        num_int=$((10#$num))
        TOTAL_PIXELS=$(identify -format '%[fx:w*h]' "$ref_png" 2>/dev/null || echo 0)
        if [ "$TOTAL_PIXELS" -gt 0 ] 2>/dev/null; then
            DIFF_NUM=${DIFF_PIXELS%%.*}
            DIFF_NUM=${DIFF_NUM//[^0-9]/}
            if [ -n "$DIFF_NUM" ]; then
                SIM=$(awk "BEGIN { printf \"%.1f\", (1 - $DIFF_NUM / $TOTAL_PIXELS) * 100 }")
                DIFF_SIM_MAP["$num_int"]="$SIM"
                DIFF_SIM_COUNT=$((DIFF_SIM_COUNT + 1))
                echo "  [$num_int] Similarity: ${SIM}%"
            fi
        fi
    done
    echo "  Generated $DIFF_COUNT diff images."

    if [ "$DIFF_SIM_COUNT" -gt 0 ]; then
        SUM=0
        for v in "${DIFF_SIM_MAP[@]}"; do
            SUM=$(awk "BEGIN { printf \"%.1f\", $SUM + $v }")
        done
        AVG_SIM=$(awk "BEGIN { printf \"%.1f\", $SUM / $DIFF_SIM_COUNT }")
        echo "  AVG similarity: ${AVG_SIM}%"
    fi
else
    if [ "$NO_DIFF" -eq 0 ] && [ "$ONLY_VV" -eq 0 ]; then
        echo "  Skipped (no ImageMagick)."
    fi
fi

# ── Generate HTML report ───────────────────────────────────────────
if [ "$NO_HTML" -eq 0 ]; then
    echo "[6/6] Generating HTML report..."
    REPORT="$OUT_DIR/report.html"
    REPORT_GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    EXT="png"

    TESTS=()
    for vv in "$OUT_DIR"/test_*_vv.$EXT; do
        [ -f "$vv" ] || continue
        base=$(basename "$vv" | sed "s/_vv\.$EXT//")
        TESTS+=("$base")
    done
    NUM_TESTS=${#TESTS[@]}

    declare -A SIM_MAP
    if [ "$DIFF_SIM_COUNT" -gt 0 ]; then
        for key in "${!DIFF_SIM_MAP[@]}"; do
            SIM_MAP["$key"]="${DIFF_SIM_MAP[$key]}"
        done

        # Save to current run file
        rm -f "$CURR_SIM_FILE"
        for key in $(printf '%s\n' "${!SIM_MAP[@]}" | sort -n); do
            echo "$key ${SIM_MAP[$key]}" >> "$CURR_SIM_FILE"
        done
    fi

    DIFF_SUMMARY_HTML=""
    if [ -f "$PREV_SIM_FILE" ] && [ "$DIFF_SIM_COUNT" -gt 0 ]; then
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

    cat > "$REPORT" << 'HEADER'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>SfDataGrid vs VolvoxGrid — Comparison Report</title>
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

.test-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 16px; }
.test-grid .cell { min-width: 0; }
.cell-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
.label-script { color: #8b949e; }
.label-diff   { color: #f85149; }
.label-ref    { color: #f0883e; }
.label-vv     { color: #58a6ff; }

.cell pre { background: #0d1117; border: 1px solid #30363d; border-radius: 6px; padding: 12px; font-size: 12.5px; line-height: 1.6; color: #e6edf3; overflow-x: auto; white-space: pre-wrap; word-break: break-word; font-family: 'Cascadia Code', 'Consolas', 'Courier New', monospace; margin: 0; max-height: 400px; overflow-y: auto; }
.cell img { width: 100%; border: 1px solid #30363d; border-radius: 4px; image-rendering: pixelated; display: block; background: white; }
.cell .placeholder { background: #0d1117; border: 1px solid #30363d; border-radius: 4px; padding: 40px; text-align: center; color: #484f58; font-size: 13px; }
</style>
</head>
<body>
<h1>SfDataGrid vs VolvoxGrid — Visual Comparison</h1>
HEADER
    echo "<div class=\"generated-at\">Generated: $REPORT_GENERATED_AT</div>" >> "$REPORT"

    if [ -n "$DIFF_SUMMARY_HTML" ]; then
        echo "$DIFF_SUMMARY_HTML" >> "$REPORT"
    fi

    {
        echo "<div class=\"summary\">"
        echo "  <div class=\"stat\"><div class=\"num\">$NUM_TESTS</div><div class=\"label\">Tests</div></div>"
        if [ "$ONLY_VV" -eq 0 ]; then
            echo "  <div class=\"stat\"><div class=\"num\">2</div><div class=\"label\">Controls</div></div>"
        fi
        if [ -n "$AVG_SIM" ]; then
            echo "  <div class=\"stat\"><div class=\"num\">${AVG_SIM}%</div><div class=\"label\">Avg Similarity</div></div>"
        fi
        echo "</div>"
    } >> "$REPORT"

    declare -A SCRIPT_MAP_DART
    SCRIPTS_JSON_FILE="$OUT_DIR/scripts.json"
    if [ -f "$SCRIPTS_JSON_FILE" ] && command -v python3 >/dev/null 2>&1; then
        while IFS=$'\t' read -r key val_b64; do
            SCRIPT_MAP_DART["$key"]="$val_b64"
        done < <(python3 -c "
import base64, json
with open('$SCRIPTS_JSON_FILE') as f:
    m = json.load(f)
for k, v in m.items():
    b = base64.b64encode(v.encode('utf-8')).decode('ascii')
    print(k + '\t' + b)
" 2>/dev/null || true)
    elif [ -f "$SCRIPTS_JSON_FILE" ]; then
        while IFS=$'\t' read -r key val_b64; do
            SCRIPT_MAP_DART["$key"]="$val_b64"
        done < <(node -e "
            import { readFileSync } from 'node:fs';
            const m = JSON.parse(readFileSync('$SCRIPTS_JSON_FILE', 'utf8'));
            for (const [k,v] of Object.entries(m)) {
                process.stdout.write(k + '\t' + Buffer.from(v, 'utf8').toString('base64') + '\n');
            }
        " 2>/dev/null || true)
    fi

    for base in "${TESTS[@]}"; do
        num="${base#test_}"
        num="${num%%_*}"
        num_int=$((10#$num))
        name="${base#test_${num}_}"

        set +u; sim_val="${SIM_MAP[$num_int]:-}"; set -u
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

        set +u; script_b64="${SCRIPT_MAP_DART[$num]:-}"; set -u
        script_content=""
        if [ -n "$script_b64" ] && command -v python3 >/dev/null 2>&1; then
            script_content=$(python3 -c "
import base64, sys
try:
    sys.stdout.write(base64.b64decode(sys.argv[1]).decode('utf-8'))
except Exception:
    pass
" "$script_b64" 2>/dev/null || true)
        fi

        if [ -z "$script_content" ]; then
            script_content="// test case $num: $name"
        fi
        script_escaped=$(echo "$script_content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

        {
            echo "<div class=\"test\">"
            echo "  <div class=\"test-header\">"
            echo "    <span class=\"num\">$num</span>"
            echo "    <h2>$name</h2>"
            echo "    $sim_badge"
            echo "  </div>"
            echo "  <div class=\"test-grid\">"

            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-script\">Dart</div>"
            echo "      <pre>$script_escaped</pre>"
            echo "    </div>"

            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-diff\">Diff</div>"
            if [ "$ONLY_VV" -eq 0 ] && [ -f "$OUT_DIR/${base}_diff.$EXT" ]; then
                echo "      <img src=\"${base}_diff.$EXT\">"
            else
                echo "      <div class=\"placeholder\">No diff (single control mode)</div>"
            fi
            echo "    </div>"

            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-ref\">SfDataGrid</div>"
            if [ "$ONLY_VV" -eq 0 ] && [ -f "$OUT_DIR/${base}_ref.$EXT" ]; then
                echo "      <img src=\"${base}_ref.$EXT\">"
            else
                echo "      <div class=\"placeholder\">No reference image</div>"
            fi
            echo "    </div>"

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
    echo "[6/6] Skipping HTML report (--no-html)."
fi

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  Output: $OUT_DIR/"
ls "$OUT_DIR"/*.png 2>/dev/null | wc -l | xargs -I{} echo "  Images: {} files"
[ -f "$OUT_DIR/report.html" ] && echo "  Report: $OUT_DIR/report.html"
[ "$TEST_EXIT" -ne 0 ] && echo "  Test exit: $TEST_EXIT"
echo "════════════════════════════════════════════════"

if [ "$TEST_EXIT" -ne 0 ]; then
    exit "$TEST_EXIT"
fi
