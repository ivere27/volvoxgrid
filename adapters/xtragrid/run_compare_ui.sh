#!/bin/bash
# run_compare_ui.sh — Execute shared C# WinForms scenarios against
# DevExpress XtraGrid and VolvoxGrid.DotNet, capture screenshots,
# generate pixel diffs, and build an HTML report.
#
# Usage:
#   ./run_compare_ui.sh [release|--release] [--only-vv] [--no-html] [--no-diff]
#       [--skip-build] [--test N] [--tests LIST]
#       [--ref-grid-assembly PATH]
#       [--width N] [--height N] [--settle-ms N]
#
# Environment:
#   REF_GRID_ASSEMBLY    Path to DevExpress.XtraGrid.vXX.Y.dll
#   WINEPREFIX           Wine prefix (default: target/xtragrid/wineprefix, reused across runs)
#   WINE_MONO_VERSION    Wine Mono version for prefix bootstrap (default: 6.0.0)
#   WINE_CMD_TIMEOUT     Per Wine command timeout seconds (default: 120)
#   XVFB_SCREEN          Xvfb screen (default: 1920x1080x24)

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="$(pwd)/$SCRIPT_PATH"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR"

PROFILE="debug"
RUNNER_CFG="Debug"
ONLY_VV=0
NO_HTML=0
NO_DIFF=0
SKIP_BUILD=0
TEST_FILTER=""
REF_GRID_ASSEMBLY="${REF_GRID_ASSEMBLY:-}"
DEFAULT_WINE_PREFIX="$ROOT_DIR/target/xtragrid/wineprefix"
NATIVE_WINE_PREFIX_CANDIDATES=(
    "$ROOT_DIR/target/xtragrid/wineprefix"
    "$ROOT_DIR/target/xtragrid/wineprefix_dotnet462"
    "$ROOT_DIR/target/xtragrid/wineprefix_dotnet462_wine11"
)
MONO_VERSION="${WINE_MONO_VERSION:-6.0.0}"
WINE_CMD_TIMEOUT="${WINE_CMD_TIMEOUT:-120}"
XVFB_SCREEN="${XVFB_SCREEN:-1920x1080x24}"
RUNNER_EXTRA_ARGS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        release|--release)
            PROFILE="release"
            RUNNER_CFG="Release"
            shift
            ;;
        --only-vv)
            ONLY_VV=1
            shift
            ;;
        --no-html)
            NO_HTML=1
            shift
            ;;
        --no-diff)
            NO_DIFF=1
            shift
            ;;
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --test|--tests)
            TEST_FILTER="$2"
            shift 2
            ;;
        --test=*|--tests=*)
            TEST_FILTER="${1#*=}"
            shift
            ;;
        --ref-grid-assembly)
            REF_GRID_ASSEMBLY="$2"
            shift 2
            ;;
        --ref-grid-assembly=*)
            REF_GRID_ASSEMBLY="${1#*=}"
            shift
            ;;
        --width|--height|--settle-ms)
            RUNNER_EXTRA_ARGS+=("$1" "$2")
            shift 2
            ;;
        --width=*|--height=*|--settle-ms=*)
            RUNNER_EXTRA_ARGS+=("$1")
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if ! [[ "$WINE_CMD_TIMEOUT" =~ ^[0-9]+$ ]] || [ "$WINE_CMD_TIMEOUT" -lt 1 ]; then
    echo "ERROR: WINE_CMD_TIMEOUT must be a positive integer" >&2
    exit 1
fi

runner_args_has_option() {
    local option="$1"
    local arg
    for arg in "${RUNNER_EXTRA_ARGS[@]}"; do
        case "$arg" in
            "$option"|"$option="*)
                return 0
                ;;
        esac
    done
    return 1
}

NUGET_ROOT_CANDIDATES=()

append_nuget_root_candidate() {
    local candidate="${1:-}"
    local existing=""

    if [ -z "$candidate" ]; then
        return 0
    fi

    candidate="${candidate%/}"
    candidate="${candidate%\\}"
    if [ -z "$candidate" ]; then
        return 0
    fi

    for existing in "${NUGET_ROOT_CANDIDATES[@]}"; do
        if [ "$existing" = "$candidate" ]; then
            return 0
        fi
    done

    NUGET_ROOT_CANDIDATES+=("$candidate")
}

collect_nuget_root_candidates() {
    local dotnet_global_packages=""

    NUGET_ROOT_CANDIDATES=()
    append_nuget_root_candidate "${NUGET_PACKAGES:-}"

    if command -v dotnet >/dev/null 2>&1; then
        dotnet_global_packages="$(dotnet nuget locals global-packages --list 2>/dev/null | sed -n 's/^global-packages: //p' | head -n 1)"
        append_nuget_root_candidate "$dotnet_global_packages"
    fi

    if [ -n "${HOME:-}" ]; then
        append_nuget_root_candidate "$HOME/.nuget/packages"
    fi
}

prefer_nuget_packages_root_for_ref() {
    local ref_relative_path="$1"
    local reason="$2"
    local candidate=""

    collect_nuget_root_candidates
    for candidate in "${NUGET_ROOT_CANDIDATES[@]}"; do
        if [ -f "$candidate/$ref_relative_path" ]; then
            if [ "${NUGET_PACKAGES:-}" != "$candidate" ]; then
                export NUGET_PACKAGES="$candidate"
                echo "  Using NuGet package cache for ${reason}: $candidate"
            fi
            return 0
        fi
    done

    return 1
}

find_reference_nupkg() {
    local nupkg_name="$1"
    local package_relative_path="$2"
    local candidate=""
    local offline_candidate="$ROOT_DIR/target/xtragrid/nuget-offline/$nupkg_name"

    if [ -f "$offline_candidate" ]; then
        printf '%s\n' "$offline_candidate"
        return 0
    fi

    collect_nuget_root_candidates
    for candidate in "${NUGET_ROOT_CANDIDATES[@]}"; do
        if [ -f "$candidate/$package_relative_path" ]; then
            printf '%s\n' "$candidate/$package_relative_path"
            return 0
        fi
    done

    return 1
}

build_runner_project() {
    local offline_feed="$ROOT_DIR/target/xtragrid/nuget-offline"
    local offline_config="$offline_feed/nuget.config"
    local meta_name="microsoft.netframework.referenceassemblies.1.0.3.nupkg"
    local meta_rel="microsoft.netframework.referenceassemblies/1.0.3/${meta_name}"
    local runner_name="microsoft.netframework.referenceassemblies.net462.1.0.3.nupkg"
    local runner_rel="microsoft.netframework.referenceassemblies.net462/1.0.3/${runner_name}"
    local meta_nupkg=""
    local runner_nupkg=""

    if meta_nupkg="$(find_reference_nupkg "$meta_name" "$meta_rel")" \
        && runner_nupkg="$(find_reference_nupkg "$runner_name" "$runner_rel")"; then
        mkdir -p "$offline_feed"
        if [ "$meta_nupkg" != "$offline_feed/$meta_name" ]; then
            cp -f "$meta_nupkg" "$offline_feed/"
        fi
        if [ "$runner_nupkg" != "$offline_feed/$runner_name" ]; then
            cp -f "$runner_nupkg" "$offline_feed/"
        fi
        cat > "$offline_config" <<EOF_OFFLINE_NUGET
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="offline" value="$offline_feed" />
  </packageSources>
</configuration>
EOF_OFFLINE_NUGET
        dotnet restore "$RUNNER_PROJECT" --configfile "$offline_config" >/dev/null
        dotnet build "$RUNNER_PROJECT" -c "$RUNNER_CFG" --no-restore >/dev/null
        return 0
    fi

    dotnet build "$RUNNER_PROJECT" -c "$RUNNER_CFG" >/dev/null
}

if ! runner_args_has_option --width; then
    RUNNER_EXTRA_ARGS+=(--width 800)
fi

if ! runner_args_has_option --height; then
    RUNNER_EXTRA_ARGS+=(--height 400)
fi

find_default_ref_grid_assembly() {
    if [ ! -d "$ROOT_DIR/legacy/devexpress" ]; then
        return 0
    fi

    find "$ROOT_DIR/legacy/devexpress" -path '*/net462/DevExpress.XtraGrid*.dll' | sort -V | tail -n 1
}

has_native_dotnet_runtime_in_prefix() {
    local prefix="$1"
    [ -f "$prefix/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/mscorlib.dll" ] \
        || [ -f "$prefix/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/mscorlib.dll" ]
}

has_native_dotnet462_runtime_in_prefix() {
    local prefix="$1"
    [ -f "$prefix/drive_c/windows/dotnet462.installed.workaround" ] \
        || { [ -f "$prefix/system.reg" ] && rg -q 'Release"=dword:00060636' "$prefix/system.reg"; }
}

select_default_wine_prefix() {
    local candidate
    for candidate in "${NATIVE_WINE_PREFIX_CANDIDATES[@]}"; do
        if has_native_dotnet462_runtime_in_prefix "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf '%s\n' "$DEFAULT_WINE_PREFIX"
}

to_wine_path() {
    local abs_path
    abs_path="$(realpath "$1")"
    abs_path="${abs_path//\//\\}"
    printf 'Z:%s\n' "$abs_path"
}

run_wine_cmd() {
    local cmd=""
    local arg
    for arg in "$@"; do
        cmd+=" $(printf '%q' "$arg")"
    done
    timeout "${WINE_CMD_TIMEOUT}s" xvfb-run -a -s "-screen 0 ${XVFB_SCREEN}" bash -lc "set -euo pipefail;${cmd}"
}

if [ -n "${WINEPREFIX:-}" ]; then
    WINE_PREFIX="$WINEPREFIX"
else
    WINE_PREFIX="$(select_default_wine_prefix)"
fi

prepare_wine_prefix() {
    export WINEPREFIX="$WINE_PREFIX"
    export WINEARCH="${WINEARCH:-win64}"

    local prefix_stamp="$WINEPREFIX/.xtragrid_prefix_ready"
    local runtime_kind="mono"
    if has_native_dotnet462_runtime_in_prefix "$WINEPREFIX"; then
        runtime_kind="native-dotnet"
    fi
    local prefix_meta="arch=$WINEARCH runtime=$runtime_kind mono=$MONO_VERSION"

    mkdir -p "$(dirname "$WINEPREFIX")"

    if [ -f "$prefix_stamp" ] \
        && { [ "$runtime_kind" = "native-dotnet" ] || [ -d "$WINEPREFIX/drive_c/windows/mono/mono-2.0" ]; } \
        && [ "$(cat "$prefix_stamp" 2>/dev/null || true)" = "$prefix_meta" ]; then
        echo "  Reusing existing Wine prefix: $WINEPREFIX"
        return 0
    fi

    echo "  Initializing Wine prefix: $WINEPREFIX"
    run_wine_cmd wineboot -u >/dev/null 2>&1 || true

    if has_native_dotnet462_runtime_in_prefix "$WINEPREFIX"; then
        echo "  Detected native .NET Framework in prefix; skipping Wine Mono bootstrap."
        runtime_kind="native-dotnet"
    elif [ ! -d "$WINEPREFIX/drive_c/windows/mono/mono-2.0" ] && ! has_native_dotnet_runtime_in_prefix "$WINEPREFIX"; then
        local mono_msi="/tmp/wine-mono-${MONO_VERSION}-x86.msi"
        if [ ! -f "$mono_msi" ]; then
            echo "  Downloading Wine Mono ${MONO_VERSION}..."
            curl -fsSL "https://dl.winehq.org/wine/wine-mono/${MONO_VERSION}/wine-mono-${MONO_VERSION}-x86.msi" -o "$mono_msi"
        fi
        echo "  Installing Wine Mono ${MONO_VERSION}..."
        run_wine_cmd wine msiexec /i "$(to_wine_path "$mono_msi")" /qn /norestart
    fi

    prefix_meta="arch=$WINEARCH runtime=$runtime_kind mono=$MONO_VERSION"

    local fonts_dir="$WINEPREFIX/drive_c/windows/Fonts"
    mkdir -p "$fonts_dir"
    if [ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ]; then
        cp -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf "$fonts_dir/dejavusans.ttf"
        cp -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf "$fonts_dir/arial.ttf"
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "DejaVu Sans (TrueType)" /t REG_SZ /d dejavusans.ttf /f >/dev/null || true
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Arial (TrueType)" /t REG_SZ /d arial.ttf /f >/dev/null || true
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Arial" /t REG_SZ /d "DejaVu Sans" /f >/dev/null || true
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Tahoma" /t REG_SZ /d "DejaVu Sans" /f >/dev/null || true
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Microsoft Sans Serif" /t REG_SZ /d "DejaVu Sans" /f >/dev/null || true
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Sans Serif" /t REG_SZ /d "DejaVu Sans" /f >/dev/null || true
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Shell Dlg" /t REG_SZ /d "DejaVu Sans" /f >/dev/null || true
        run_wine_cmd wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Shell Dlg 2" /t REG_SZ /d "DejaVu Sans" /f >/dev/null || true
    fi

    printf '%s\n' "$prefix_meta" > "$prefix_stamp"
}

html_escape_file() {
    local path="$1"
    python3 - "$path" << 'PY'
import html
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if not path.exists():
    print("")
    raise SystemExit(0)
text = path.read_text(encoding="utf-8", errors="replace")
print(html.escape(text))
PY
}

matches_test_filter() {
    local number="$1"
    local filter="$2"
    local part raw start end tmp

    if [ -z "$filter" ]; then
        return 0
    fi

    IFS=',' read -r -a parts <<< "$filter"
    for part in "${parts[@]}"; do
        raw="${part//[[:space:]]/}"
        [ -n "$raw" ] || continue

        if [[ "$raw" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start=$((10#${BASH_REMATCH[1]}))
            end=$((10#${BASH_REMATCH[2]}))
            if [ "$start" -gt "$end" ]; then
                tmp="$start"
                start="$end"
                end="$tmp"
            fi

            if [ "$number" -ge "$start" ] && [ "$number" -le "$end" ]; then
                return 0
            fi
            continue
        fi

        if [[ "$raw" =~ ^[0-9]+$ ]]; then
            if [ "$number" -eq "$((10#$raw))" ]; then
                return 0
            fi
            continue
        fi

        echo "ERROR: invalid tests filter segment: $part" >&2
        exit 1
    done

    return 1
}

discover_case_numbers() {
    local scripts_dir="$1"
    local filter="$2"
    local path file number
    declare -A seen=()

    while IFS= read -r path; do
        file="$(basename "$path")"
        if [[ "$file" =~ ^([0-9]+)[_[:space:]-].*\.csx$ ]]; then
            number=$((10#${BASH_REMATCH[1]}))
            if matches_test_filter "$number" "$filter" && [ -z "${seen[$number]+x}" ]; then
                seen[$number]=1
                printf '%s\n' "$number"
            fi
        fi
    done < <(find "$scripts_dir" -maxdepth 1 -type f -name '*.csx' | sort)
}

append_results_tsv() {
    local src="$1"
    local dest="$2"

    [ -f "$src" ] || return 0

    if [ ! -f "$dest" ]; then
        mv -f "$src" "$dest"
        return 0
    fi

    tail -n +2 "$src" >> "$dest"
    rm -f "$src"
}

run_runner_cases() {
    local engine="$1"
    local suffix="$2"
    local grid_assembly_win="$3"
    local results_dest="$4"
    local case_num case_rc overall_rc=0

    rm -f "$results_dest"

    for case_num in "${CASE_NUMBERS[@]}"; do
        rm -f "$OUT_DIR/results.tsv"

        set +e
        if [ "$engine" = "vv" ]; then
            run_wine_cmd env VOLVOXGRID_PLUGIN_PATH="$VV_PLUGIN_WIN" wine "$RUNNER_WIN" \
                --engine "$engine" \
                --suffix "$suffix" \
                --grid-assembly "$grid_assembly_win" \
                --plugin-path "$VV_PLUGIN_WIN" \
                "${RUNNER_BASE_ARGS[@]}" \
                --tests "$case_num" | tee -a "$COMPARE_LOG"
        else
            run_wine_cmd wine "$RUNNER_WIN" \
                --engine "$engine" \
                --suffix "$suffix" \
                --grid-assembly "$grid_assembly_win" \
                "${RUNNER_BASE_ARGS[@]}" \
                --tests "$case_num" | tee -a "$COMPARE_LOG"
        fi
        case_rc=${PIPESTATUS[0]}
        set -e

        append_results_tsv "$OUT_DIR/results.tsv" "$results_dest"
        if [ "$case_rc" -ne 0 ]; then
            overall_rc="$case_rc"
        fi
    done

    return "$overall_rc"
}

echo "=== XtraGrid vs VolvoxGrid.DotNet — C# Script Compare ==="
echo ""

RUNNER_PROJECT="$ROOT_DIR/adapters/xtragrid/test/runner/DotNetGrid.ScriptRunner.csproj"
SCRIPTS_DIR="$ROOT_DIR/adapters/xtragrid/test/cases"
OUT_DIR="$ROOT_DIR/target/xtragrid/compare"
COMPARE_LOG="$OUT_DIR/compare_output.log"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/test_*_vv.png "$OUT_DIR"/test_*_ref.png "$OUT_DIR"/test_*_diff.png \
    "$OUT_DIR"/report.html "$COMPARE_LOG" "$OUT_DIR"/results.tsv \
    "$OUT_DIR"/results_vv.tsv "$OUT_DIR"/results_ref.tsv

if [ -z "$REF_GRID_ASSEMBLY" ]; then
    REF_GRID_ASSEMBLY="$(find_default_ref_grid_assembly || true)"
fi

if [ "$SKIP_BUILD" -eq 0 ]; then
    echo "[1/6] Building VolvoxGrid .NET artifacts..."
    prefer_nuget_packages_root_for_ref "microsoft.netframework.referenceassemblies.net40/1.0.3/build/.NETFramework/v4.0/mscorlib.dll" "net40 build" || true
    if [ "$PROFILE" = "release" ]; then
        DOTNET_TFM=net40 "$ROOT_DIR/dotnet/build_dotnet.sh" release
    else
        DOTNET_TFM=net40 "$ROOT_DIR/dotnet/build_dotnet.sh"
    fi
else
    echo "[1/6] Skipping VolvoxGrid build (--skip-build)"
fi

echo "[2/6] Building C# script runner..."
prefer_nuget_packages_root_for_ref "microsoft.netframework.referenceassemblies.net462/1.0.3/build/.NETFramework/v4.6.2/mscorlib.dll" "net462 runner build" || true
build_runner_project

RUNNER_EXE="$ROOT_DIR/adapters/xtragrid/test/runner/bin/${RUNNER_CFG}/net462/DotNetGrid.ScriptRunner.exe"
VV_STAGE="$ROOT_DIR/target/dotnet/winforms_${PROFILE}"
VV_GRID_ASM="$VV_STAGE/VolvoxGrid.DotNet.dll"
VV_PLUGIN_DLL="$VV_STAGE/volvoxgrid_plugin.dll"

[ -f "$RUNNER_EXE" ] || { echo "ERROR: runner exe not found: $RUNNER_EXE" >&2; exit 1; }
[ -f "$VV_GRID_ASM" ] || { echo "ERROR: Volvox grid assembly not found: $VV_GRID_ASM" >&2; exit 1; }
[ -f "$VV_PLUGIN_DLL" ] || { echo "ERROR: plugin dll not found: $VV_PLUGIN_DLL" >&2; exit 1; }

echo "[3/6] Preparing Wine prefix..."
prepare_wine_prefix

RUNNER_WIN="$(to_wine_path "$RUNNER_EXE")"
SCRIPTS_WIN="$(to_wine_path "$SCRIPTS_DIR")"
OUT_WIN="$(to_wine_path "$OUT_DIR")"
VV_ASM_WIN="$(to_wine_path "$VV_GRID_ASM")"
VV_PLUGIN_WIN="$(to_wine_path "$VV_PLUGIN_DLL")"

RUNNER_BASE_ARGS=(--scripts-dir "$SCRIPTS_WIN" --out-dir "$OUT_WIN")
RUNNER_BASE_ARGS+=("${RUNNER_EXTRA_ARGS[@]}")
mapfile -t CASE_NUMBERS < <(discover_case_numbers "$SCRIPTS_DIR" "$TEST_FILTER")
if [ "${#CASE_NUMBERS[@]}" -eq 0 ]; then
    echo "No script cases selected."
    exit 0
fi

OVERALL_RC=0

echo "[4/6] Running VolvoxGrid.DotNet scripts..."
VV_RUN_RC=0
run_runner_cases vv vv "$VV_ASM_WIN" "$OUT_DIR/results_vv.tsv" || VV_RUN_RC=$?
if [ "$VV_RUN_RC" -ne 0 ]; then
    echo "WARNING: VolvoxGrid.DotNet run exited with code $VV_RUN_RC; generating report from available artifacts."
    OVERALL_RC=1
fi

if [ "$ONLY_VV" -eq 0 ]; then
    if [ -z "$REF_GRID_ASSEMBLY" ]; then
        echo "WARNING: no DevExpress XtraGrid assembly configured; switching to --only-vv mode."
        ONLY_VV=1
    elif [ ! -f "$REF_GRID_ASSEMBLY" ]; then
        echo "WARNING: reference grid assembly not found: $REF_GRID_ASSEMBLY"
        echo "         switching to --only-vv mode."
        ONLY_VV=1
    fi
fi

if [ "$ONLY_VV" -eq 0 ]; then
    echo "[5/6] Running DevExpress XtraGrid scripts..."
    REF_ASM_WIN="$(to_wine_path "$REF_GRID_ASSEMBLY")"
    REF_RUN_RC=0
    run_runner_cases ref ref "$REF_ASM_WIN" "$OUT_DIR/results_ref.tsv" || REF_RUN_RC=$?
    if [ "$REF_RUN_RC" -ne 0 ]; then
        echo "WARNING: reference run exited with code $REF_RUN_RC; report may be partial."
        OVERALL_RC=1
    fi
else
    echo "[5/6] Skipping DevExpress run (--only-vv)."
fi

declare -A SIM_MAP=()
HAS_IMAGEMAGICK=0
if [ "$NO_DIFF" -eq 0 ] && [ "$ONLY_VV" -eq 0 ]; then
    if command -v compare >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
        HAS_IMAGEMAGICK=1
    else
        echo "WARNING: ImageMagick compare/identify not found; skipping diffs."
    fi
fi

if [ "$HAS_IMAGEMAGICK" -eq 1 ]; then
    for vv_png in "$OUT_DIR"/test_*_vv.png; do
        [ -f "$vv_png" ] || continue
        base="${vv_png%_vv.png}"
        ref_png="${base}_ref.png"
        diff_png="${base}_diff.png"
        [ -f "$ref_png" ] || continue

        diff_pixels="$(compare -metric AE -fuzz 5% "$ref_png" "$vv_png" "$diff_png" 2>&1 || true)"
        total_pixels="$(identify -format '%[fx:w*h]' "$ref_png" 2>/dev/null || echo 0)"
        num="$(basename "$base" | sed -E 's/^test_([0-9]+)_.*/\1/')"
        if [ "${total_pixels:-0}" -gt 0 ] 2>/dev/null; then
            diff_num="${diff_pixels%%.*}"
            diff_num="${diff_num//[^0-9]/}"
            if [ -n "$diff_num" ]; then
                sim="$(awk "BEGIN { printf \"%.1f\", (1 - $diff_num / $total_pixels) * 100 }")"
                SIM_MAP["$num"]="$sim"
            fi
        fi
    done
fi

if [ "$NO_HTML" -eq 0 ]; then
    echo "[6/6] Generating HTML report..."
    REPORT="$OUT_DIR/report.html"
    GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"

    TEST_BASES=()
    for vv in "$OUT_DIR"/test_*_vv.png; do
        [ -f "$vv" ] || continue
        TEST_BASES+=("${vv%_vv.png}")
    done
    IFS=$'\n' TEST_BASES=($(printf '%s\n' "${TEST_BASES[@]}" | sort))

    NUM_TESTS="${#TEST_BASES[@]}"
    NUM_CONTROLS=1
    if [ "$ONLY_VV" -eq 0 ]; then
        NUM_CONTROLS=2
    fi

    AVG_SIM="n/a"
    if [ "${#SIM_MAP[@]}" -gt 0 ]; then
        AVG_SIM="$(printf '%s\n' "${SIM_MAP[@]}" | awk '{sum+=$1; n++} END { if (n > 0) printf "%.1f%%", sum / n; else print "n/a" }')"
    fi

    cat > "$REPORT" << 'HTML_HEAD'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>XtraGrid vs VolvoxGrid — Comparison Report</title>
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
<h1>XtraGrid vs VolvoxGrid — Visual Comparison</h1>
HTML_HEAD
    echo "<div class=\"generated-at\">Generated: ${GENERATED_AT}</div>" >> "$REPORT"
    {
        echo "<div class=\"summary\">"
        echo "  <div class=\"stat\"><div class=\"num\">${NUM_TESTS}</div><div class=\"label\">Tests</div></div>"
        echo "  <div class=\"stat\"><div class=\"num\">${NUM_CONTROLS}</div><div class=\"label\">Controls</div></div>"
        echo "  <div class=\"stat\"><div class=\"num\">${AVG_SIM}</div><div class=\"label\">Avg Similarity</div></div>"
        echo "</div>"
    } >> "$REPORT"

    for base in "${TEST_BASES[@]}"; do
        base_name="$(basename "$base")"
        num="$(echo "$base_name" | sed -E 's/^test_([0-9]+)_.*/\1/')"
        case_name="$(echo "$base_name" | sed -E 's/^test_[0-9]+_//' | tr '_' ' ')"
        script_file="${base}_script.csx"
        vv_png="${base}_vv.png"
        ref_png="${base}_ref.png"
        diff_png="${base}_diff.png"

        sim="${SIM_MAP[$num]:-}"
        sim_badge=""
        if [ -n "$sim" ]; then
            sim_int="${sim%.*}"
            if [ "${sim_int:-0}" -ge 90 ]; then
                sim_class="match-high"
            elif [ "${sim_int:-0}" -ge 75 ]; then
                sim_class="match-mid"
            else
                sim_class="match-low"
            fi
            sim_badge="<span class=\"match ${sim_class}\">${sim}%</span>"
        elif [ "$ONLY_VV" -eq 1 ]; then
            sim_badge="<span class=\"match match-mid\">Volvox only</span>"
        else
            sim_badge="<span class=\"match match-low\">n/a</span>"
        fi

        script_html="$(html_escape_file "$script_file")"
        script_html="${script_html//$'\n'/<br/>}"

        {
            echo "<div class=\"test\">"
            echo "  <div class=\"test-header\">"
            echo "    <span class=\"num\">${num}</span>"
            echo "    <h2>${case_name}</h2>"
            echo "    ${sim_badge}"
            echo "  </div>"
            echo "  <div class=\"test-grid\">"
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-script\">C# Script</div>"
            echo "      <pre>${script_html}</pre>"
            echo "    </div>"
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-diff\">Diff</div>"
            if [ "$NO_DIFF" -eq 0 ] && [ -f "$diff_png" ]; then
                rel_diff="$(basename "$diff_png")"
                echo "      <img src=\"${rel_diff}\">"
            else
                echo "      <div class=\"placeholder\">No diff (single control mode)</div>"
            fi
            echo "    </div>"
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-ref\">DevExpress XtraGrid</div>"
            if [ "$ONLY_VV" -eq 0 ] && [ -f "$ref_png" ]; then
                rel_ref="$(basename "$ref_png")"
                echo "      <img src=\"${rel_ref}\">"
            else
                echo "      <div class=\"placeholder\">Not available</div>"
            fi
            echo "    </div>"
            echo "    <div class=\"cell\">"
            echo "      <div class=\"cell-label label-vv\">VolvoxGrid .NET</div>"
            if [ -f "$vv_png" ]; then
                rel_vv="$(basename "$vv_png")"
                echo "      <img src=\"${rel_vv}\">"
            else
                echo "      <div class=\"placeholder\">Missing image</div>"
            fi
            echo "    </div>"
            echo "  </div>"
            echo "</div>"
        } >> "$REPORT"
    done

    echo "</body></html>" >> "$REPORT"
    echo "Report: $REPORT"
else
    echo "[6/6] Skipping HTML (--no-html)"
fi

echo ""
echo "Done. Output dir: $OUT_DIR"
exit "$OVERALL_RC"
