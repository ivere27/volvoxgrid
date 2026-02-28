#!/bin/bash
# run_compare_ui.sh — Capture per-case screenshots of AG Grid vs VolvoxGrid,
# generate pixel diffs and HTML comparison report.
#
# Usage:
#   ./run_compare_ui.sh [--only-vv] [--no-html] [--no-diff] [--skip-build] [--test N] [--tests LIST] [--settle-ms N] [--grid-width N] [--grid-height N] [--viewport-width N] [--viewport-height N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$ROOT_DIR/target/aggrid/compare"
COMPARE_LOG="$OUT_DIR/compare_output.log"

NO_HTML=0
NO_DIFF=0
ONLY_VV=0
SKIP_BUILD=0
EXTRA_ARGS=()
DEFAULT_GRID_WIDTH="${VOLVOXGRID_COMPARE_GRID_WIDTH:-820}"
DEFAULT_GRID_HEIGHT="${VOLVOXGRID_COMPARE_GRID_HEIGHT:-560}"

for arg in "$@"; do
    case "$arg" in
        --no-html) NO_HTML=1 ;;
        --no-diff) NO_DIFF=1 ;;
        --skip-build) SKIP_BUILD=1 ;;
        --only-vv) ONLY_VV=1; EXTRA_ARGS+=("$arg") ;;
        *) EXTRA_ARGS+=("$arg") ;;
    esac
done

mkdir -p "$OUT_DIR"
# Rotate previous similarity mapping
CURR_SIM_FILE="$OUT_DIR/curr_sim.txt"
PREV_SIM_FILE="$OUT_DIR/prev_sim.txt"
if [ -f "$CURR_SIM_FILE" ]; then
    mv -f "$CURR_SIM_FILE" "$PREV_SIM_FILE"
fi

# Remove stale capture artifacts so partial test runs stay fast and accurate.
rm -f "$OUT_DIR"/test_*_ref.png "$OUT_DIR"/test_*_vv.png "$OUT_DIR"/test_*_diff.png "$OUT_DIR"/scripts.json "$OUT_DIR"/report.html

# ── Preflight ──────────────────────────────────────────────────────
echo "=== AG Grid vs VolvoxGrid — Capture Compare ==="
echo ""

command -v node >/dev/null 2>&1 || { echo "ERROR: node not found"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "ERROR: npx not found"; exit 1; }

HAS_IMAGEMAGICK=0
if [ "$NO_DIFF" -eq 0 ]; then
    if command -v compare >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
        HAS_IMAGEMAGICK=1
    else
        echo "WARNING: ImageMagick (compare/identify) not found — skipping diff images"
    fi
fi

# ── Detect capture font for WASM text rendering ───────────────────
CAPTURE_FONT_PATH="${VOLVOXGRID_COMPARE_FONT:-}"
CAPTURE_FONT_FAMILY="${VOLVOXGRID_COMPARE_FONT_FAMILY:-}"
FALLBACK_FONT_PATH=""

if [ -n "$CAPTURE_FONT_PATH" ] && [ ! -f "$CAPTURE_FONT_PATH" ]; then
    echo "WARNING: VOLVOXGRID_COMPARE_FONT is set but file was not found: $CAPTURE_FONT_PATH"
    CAPTURE_FONT_PATH=""
fi

if [ -z "$CAPTURE_FONT_PATH" ]; then
    FONT_CANDIDATES=(
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf|DejaVu Sans"
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf|Liberation Sans"
        "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf|Noto Sans"
        "/usr/share/fonts/noto/NotoSans-Regular.ttf|Noto Sans"
        "/System/Library/Fonts/Supplemental/Arial.ttf|Arial"
        "/Library/Fonts/Arial.ttf|Arial"
    )

    for entry in "${FONT_CANDIDATES[@]}"; do
        candidate_path="${entry%%|*}"
        candidate_family="${entry#*|}"
        if [ -f "$candidate_path" ]; then
            CAPTURE_FONT_PATH="$candidate_path"
            CAPTURE_FONT_FAMILY="$candidate_family"
            break
        fi
    done
fi

if [ -n "$CAPTURE_FONT_PATH" ]; then
    if [ -z "$CAPTURE_FONT_FAMILY" ]; then
        CAPTURE_FONT_FAMILY="Sans"
    fi
    echo "Using VolvoxGrid capture font: $CAPTURE_FONT_FAMILY ($CAPTURE_FONT_PATH)"
else
    echo "WARNING: No local TTF font found for WASM capture; VolvoxGrid text may be blank."
fi

# CJK fallback font removed — canvas2d rasterizer handles missing glyphs.

# ── Install dependencies ──────────────────────────────────────────
echo "[check] Checking dependencies..."
cd "$SCRIPT_DIR"
if [ ! -d "node_modules/puppeteer" ] || [ ! -d "node_modules/ag-grid-community" ]; then
    echo "  Running npm install..."
    npm install --no-audit --no-fund 2>&1 | tail -3
fi
echo "  Done."

if [ "$SKIP_BUILD" -eq 0 ]; then
    # ── Build VolvoxGrid WASM + web runtime + TypeScript adapter ────
    echo "[build] Building VolvoxGrid WASM runtime (dist/wasm)..."
    command -v wasm-pack >/dev/null 2>&1 || { echo "ERROR: wasm-pack not found"; exit 1; }
    (cd "$ROOT_DIR/web/crate" && rustup run nightly wasm-pack build . --release --target web --out-dir "$ROOT_DIR/dist/wasm" --features gpu) >/dev/null
    echo "  Done."

    echo "[build] Building VolvoxGrid web JS runtime..."
    if [ ! -d "$ROOT_DIR/web/js/node_modules/typescript" ]; then
        echo "  Installing web/js dependencies..."
        (cd "$ROOT_DIR/web/js" && npm install --no-audit --no-fund) 2>&1 | tail -3
    fi
    (cd "$ROOT_DIR/web/js" && npm run build) >/dev/null
    echo "  Done."

    echo "[build] Building TypeScript adapter..."
    npx tsc -p tsconfig.json
    echo "  Done."
else
    echo "[build] Skipping builds (--skip-build)"
fi

# ── Run Puppeteer capture ────────────────────────────────────────
echo "[capture] Running Puppeteer capture..."
CAPTURE_ARGS=(
    test/capture_compare.mjs
    --out "$OUT_DIR"
    --grid-width "$DEFAULT_GRID_WIDTH"
    --grid-height "$DEFAULT_GRID_HEIGHT"
)
CAPTURE_ARGS+=("${EXTRA_ARGS[@]}")
if [ -n "$CAPTURE_FONT_PATH" ]; then
    CAPTURE_ARGS+=(--font "$CAPTURE_FONT_PATH" --font-family "$CAPTURE_FONT_FAMILY")
fi
node "${CAPTURE_ARGS[@]}" 2>&1 | tee "$COMPARE_LOG"
echo "  Done."

# ── Generate diff images ─────────────────────────────────────────
if [ "$NO_DIFF" -eq 1 ]; then
    echo "[diff] Skipped (--no-diff)."
else
    echo "[diff] Generating diff images..."
fi

DIFF_COUNT=0
declare -A SIM_MAP

if [ "$HAS_IMAGEMAGICK" -eq 1 ]; then
    for ref_png in "$OUT_DIR"/test_*_ref.png; do
        [ -f "$ref_png" ] || continue
        base=$(basename "$ref_png" | sed 's/_ref\.png//')
        vv_png="$OUT_DIR/${base}_vv.png"
        diff_png="$OUT_DIR/${base}_diff.png"

        if [ ! -f "$vv_png" ]; then
            continue
        fi

        # Generate diff image
        DIFF_PIXELS=$(compare -metric AE -fuzz 5% "$ref_png" "$vv_png" "$diff_png" 2>&1 || true)
        DIFF_COUNT=$((DIFF_COUNT + 1))

        # Compute similarity
        num="${base#test_}"
        num="${num%%_*}"

        TOTAL_PIXELS=$(identify -format '%[fx:w*h]' "$ref_png" 2>/dev/null || echo 0)
        if [ "$TOTAL_PIXELS" -gt 0 ] 2>/dev/null; then
            DIFF_NUM=${DIFF_PIXELS%%.*}
            DIFF_NUM=${DIFF_NUM//[^0-9]/}
            if [ -n "$DIFF_NUM" ]; then
                SIM=$(awk "BEGIN { printf \"%.1f\", (1 - $DIFF_NUM / $TOTAL_PIXELS) * 100 }")
                SIM_MAP["$num"]="$SIM"
                echo "  [$num] Similarity: ${SIM}%"
            fi
        fi
    done
    echo "  Generated $DIFF_COUNT diff images."

    # Compute average
    if [ "${#SIM_MAP[@]}" -gt 0 ]; then
        SUM=0
        for v in "${SIM_MAP[@]}"; do
            SUM=$(awk "BEGIN { printf \"%.1f\", $SUM + $v }")
        done
        AVG_SIM=$(awk "BEGIN { printf \"%.1f\", $SUM / ${#SIM_MAP[@]} }")
        echo "  AVG similarity: ${AVG_SIM}%"

        # Save to current run file
        rm -f "$CURR_SIM_FILE"
        for key in $(printf '%s\n' "${!SIM_MAP[@]}" | sort -n); do
            echo "$key ${SIM_MAP[$key]}" >> "$CURR_SIM_FILE"
        done
    fi
else
    if [ "$NO_DIFF" -eq 0 ]; then
        echo "  Skipped (no ImageMagick)."
    fi
fi

# ── Generate HTML report ─────────────────────────────────────────
if [ "$NO_HTML" -eq 0 ]; then
    echo "[report] Generating HTML report..."
    REPORT="$OUT_DIR/report.html"
    REPORT_GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    EXT="png"

    # Collect test names
    TESTS=()
    for vv in "$OUT_DIR"/test_*_vv.$EXT; do
        [ -f "$vv" ] || continue
        base=$(basename "$vv" | sed "s/_vv\.$EXT//")
        TESTS+=("$base")
    done
    NUM_TESTS=${#TESTS[@]}

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

    # ── Write HTML ──
    cat > "$REPORT" << 'HEADER'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>AG Grid vs VolvoxGrid — Comparison Report</title>
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
.cell img { width: 100%; border: 1px solid #30363d; border-radius: 4px; image-rendering: pixelated; display: block; }
.cell .placeholder { background: #0d1117; border: 1px solid #30363d; border-radius: 4px; padding: 40px; text-align: center; color: #484f58; font-size: 13px; }
</style>
</head>
<body>
<h1>AG Grid vs VolvoxGrid — Visual Comparison</h1>
HEADER
    echo "<div class=\"generated-at\">Generated: $REPORT_GENERATED_AT</div>" >> "$REPORT"

    if [ -n "$DIFF_SUMMARY_HTML" ]; then
        echo "$DIFF_SUMMARY_HTML" >> "$REPORT"
    fi

    # Summary
    {
        echo "<div class=\"summary\">"
        echo "  <div class=\"stat\"><div class=\"num\">$NUM_TESTS</div><div class=\"label\">Tests</div></div>"
        if [ "$ONLY_VV" -eq 0 ]; then
            echo "  <div class=\"stat\"><div class=\"num\">2</div><div class=\"label\">Controls</div></div>"
        fi
        if [ -n "${AVG_SIM:-}" ]; then
            echo "  <div class=\"stat\"><div class=\"num\">${AVG_SIM}%</div><div class=\"label\">Avg Similarity</div></div>"
        fi
        echo "</div>"
    } >> "$REPORT"

    # Load scripts from scripts.json written by the Puppeteer script
    declare -A SCRIPT_MAP
    SCRIPTS_JSON_FILE="$OUT_DIR/scripts.json"
    if [ -f "$SCRIPTS_JSON_FILE" ] && command -v python3 >/dev/null 2>&1; then
        while IFS=$'\t' read -r key val_b64; do
            SCRIPT_MAP["$key"]="$val_b64"
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
            SCRIPT_MAP["$key"]="$val_b64"
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
        name="${base#test_${num}_}"

        # Get similarity for this test
        set +u; sim_val="${SIM_MAP[$num]:-}"; set -u
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

        # Get script content
        set +u; script_b64="${SCRIPT_MAP[$num]:-}"; set -u
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
        # HTML-escape
        script_escaped=$(echo "$script_content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

        {
            echo "<div class=\"test\">"
            echo "  <div class=\"test-header\">"
            echo "    <span class=\"num\">$num</span>"
            echo "    <h2>$name</h2>"
            echo "    $sim_badge"
            echo "  </div>"
            echo "  <div class=\"test-grid\">"

            # Top-left: JavaScript
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-script\">JavaScript</div>"
            echo "      <pre>$script_escaped</pre>"
            echo "    </div>"

            # Top-right: Diff
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-diff\">Diff</div>"
            if [ "$ONLY_VV" -eq 0 ] && [ -f "$OUT_DIR/${base}_diff.$EXT" ]; then
                echo "      <img src=\"${base}_diff.$EXT\">"
            else
                echo "      <div class=\"placeholder\">No diff (single control mode)</div>"
            fi
            echo "    </div>"

            # Bottom-left: AG Grid
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-ref\">AG Grid</div>"
            if [ "$ONLY_VV" -eq 0 ] && [ -f "$OUT_DIR/${base}_ref.$EXT" ]; then
                echo "      <img src=\"${base}_ref.$EXT\">"
            else
                echo "      <div class=\"placeholder\">No reference image</div>"
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
    echo "[6/6] Skipping HTML report (--no-html)."
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  Output: $OUT_DIR/"
ls "$OUT_DIR"/*.png 2>/dev/null | wc -l | xargs -I{} echo "  Images: {} files"
[ -f "$OUT_DIR/report.html" ] && echo "  Report: $OUT_DIR/report.html"
echo "════════════════════════════════════════════════"
