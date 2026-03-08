#!/bin/bash
# run_compare_ui.sh — Capture screenshots of VolvoxSheet test cases,
# generate pixel diffs and HTML comparison report.
#
# Each test case is a .txt script in test/cases/ with one API call per line.
#
# Usage:
#   ./run_compare_ui.sh [--no-html] [--no-diff] [--skip-build] [--test N] [--tests LIST] [--settle-ms N] [--grid-width N] [--grid-height N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$ROOT_DIR/target/sheet/compare"
COMPARE_LOG="$OUT_DIR/compare_output.log"

NO_HTML=0
NO_DIFF=0
SKIP_BUILD=0
EXTRA_ARGS=()
DEFAULT_GRID_WIDTH="${VOLVOXGRID_COMPARE_GRID_WIDTH:-820}"
DEFAULT_GRID_HEIGHT="${VOLVOXGRID_COMPARE_GRID_HEIGHT:-560}"

for arg in "$@"; do
    case "$arg" in
        --no-html) NO_HTML=1 ;;
        --no-diff) NO_DIFF=1 ;;
        --skip-build) SKIP_BUILD=1 ;;
        *) EXTRA_ARGS+=("$arg") ;;
    esac
done

mkdir -p "$OUT_DIR"
# Rotate previous similarity mapping (for consistency across adapters)
CURR_SIM_FILE="$OUT_DIR/curr_sim.txt"
PREV_SIM_FILE="$OUT_DIR/prev_sim.txt"
if [ -f "$CURR_SIM_FILE" ]; then
    mv -f "$CURR_SIM_FILE" "$PREV_SIM_FILE"
fi

# Remove stale capture artifacts
rm -f "$OUT_DIR"/test_*_vv.png "$OUT_DIR"/test_*_diff.png "$OUT_DIR"/scripts.json "$OUT_DIR"/report.html

# ── Preflight ──────────────────────────────────────────────────────
echo "=== VolvoxSheet — Capture Compare ==="
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

# ── Detect capture font ────────────────────────────────────────────
CAPTURE_FONT_PATH="${VOLVOXGRID_COMPARE_FONT:-}"
CAPTURE_FONT_FAMILY="${VOLVOXGRID_COMPARE_FONT_FAMILY:-}"

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
    echo "Using capture font: $CAPTURE_FONT_FAMILY ($CAPTURE_FONT_PATH)"
else
    echo "WARNING: No local TTF font found for WASM capture; text may be blank."
fi

# ── Install dependencies ──────────────────────────────────────────
echo "[check] Checking dependencies..."
cd "$SCRIPT_DIR"
if [ ! -d "node_modules/puppeteer" ]; then
    echo "  Running npm install (puppeteer)..."
    npm install --no-audit --no-fund puppeteer 2>&1 | tail -3
fi
# Ensure volvoxgrid JS dependency is linked
if [ ! -d "node_modules/volvoxgrid" ]; then
    echo "  Running npm install..."
    npm install --no-audit --no-fund 2>&1 | tail -3
fi
echo "  Done."

if [ "$SKIP_BUILD" -eq 0 ]; then
    # ── Build VolvoxGrid WASM ──────────────────────────────────────
    echo "[build] Building VolvoxGrid WASM runtime..."
    command -v wasm-pack >/dev/null 2>&1 || { echo "ERROR: wasm-pack not found"; exit 1; }
    # Build to web/example/wasm/ (symlinked from adapters/sheet/wasm/)
    (cd "$ROOT_DIR/web/crate" && rustup run nightly wasm-pack build . --release --target web --out-dir "$ROOT_DIR/web/example/wasm" --features gpu) >/dev/null
    echo "  Done."

    echo "[build] Building VolvoxGrid web JS runtime..."
    if [ ! -d "$ROOT_DIR/web/js/node_modules/typescript" ]; then
        echo "  Installing web/js dependencies..."
        (cd "$ROOT_DIR/web/js" && npm install --no-audit --no-fund) 2>&1 | tail -3
    fi
    (cd "$ROOT_DIR/web/js" && npm run build) >/dev/null
    echo "  Done."
else
    echo "[build] Skipping builds (--skip-build)"
fi

# ── Count test cases ──────────────────────────────────────────────
NUM_CASES=$(ls -1 "$SCRIPT_DIR/test/cases/"*.txt 2>/dev/null | wc -l)
echo "[cases] Found $NUM_CASES test scripts in test/cases/"

# ── Run Puppeteer capture ─────────────────────────────────────────
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

# ── Generate HTML report ─────────────────────────────────────────
if [ "$NO_HTML" -eq 0 ]; then
    echo "[report] Generating HTML report..."
    REPORT="$OUT_DIR/report.html"
    REPORT_GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"

    # Collect test images
    TESTS=()
    for vv in "$OUT_DIR"/test_*_vv.png; do
        [ -f "$vv" ] || continue
        base=$(basename "$vv" | sed 's/_vv\.png//')
        TESTS+=("$base")
    done
    NUM_TESTS=${#TESTS[@]}

    # Load scripts from scripts.json
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

    # ── Write HTML ──
    cat > "$REPORT" << 'HEADER'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>VolvoxSheet — Test Report</title>
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

.test-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 16px; }
.test-grid .cell { min-width: 0; }
.cell-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px; }
.label-script { color: #8b949e; }
.label-vv     { color: #58a6ff; }

.cell pre { background: #0d1117; border: 1px solid #30363d; border-radius: 6px; padding: 12px; font-size: 12.5px; line-height: 1.6; color: #e6edf3; overflow-x: auto; white-space: pre-wrap; word-break: break-word; font-family: 'Cascadia Code', 'Consolas', 'Courier New', monospace; margin: 0; max-height: 400px; overflow-y: auto; }
.cell img { width: 100%; border: 1px solid #30363d; border-radius: 4px; image-rendering: pixelated; display: block; }
</style>
</head>
<body>
<h1>VolvoxSheet — Test Report</h1>
HEADER
    echo "<div class=\"generated-at\">Generated: $REPORT_GENERATED_AT</div>" >> "$REPORT"

    # Summary
    {
        echo "<div class=\"summary\">"
        echo "  <div class=\"stat\"><div class=\"num\">$NUM_TESTS</div><div class=\"label\">Tests</div></div>"
        echo "  <div class=\"stat\"><div class=\"num\">$NUM_CASES</div><div class=\"label\">Scripts</div></div>"
        echo "</div>"
    } >> "$REPORT"

    # Each test
    for base in "${TESTS[@]}"; do
        num="${base#test_}"
        num="${num%%_*}"
        name="${base#test_${num}_}"

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
            script_content="# test case $num: $name"
        fi
        # HTML-escape
        script_escaped=$(echo "$script_content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

        {
            echo "<div class=\"test\">"
            echo "  <div class=\"test-header\">"
            echo "    <span class=\"num\">$num</span>"
            echo "    <h2>$name</h2>"
            echo "  </div>"
            echo "  <div class=\"test-grid\">"

            # Left: Script
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-script\">Script</div>"
            echo "      <pre>$script_escaped</pre>"
            echo "    </div>"

            # Right: Screenshot
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-vv\">VolvoxSheet</div>"
            echo "      <img src=\"${base}_vv.png\">"
            echo "    </div>"

            echo "  </div>"
            echo "</div>"
        } >> "$REPORT"
    done

    echo "</body></html>" >> "$REPORT"
    echo "  Report: $OUT_DIR/report.html"
else
    echo "[report] Skipping HTML report (--no-html)."
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "  Output: $OUT_DIR/"
ls "$OUT_DIR"/*.png 2>/dev/null | wc -l | xargs -I{} echo "  Images: {} files"
[ -f "$OUT_DIR/report.html" ] && echo "  Report: $OUT_DIR/report.html"
echo "════════════════════════════════════════════════"
