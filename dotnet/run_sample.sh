#!/bin/bash
# run_sample.sh — Run the VolvoxGrid .NET sample.
#
# Usage:
#   ./dotnet/run_sample.sh [release]
#
# Environment:
#   DOTNET_TFM=net40|net8.0-windows   (default: net40)
#   DOTNET_ARCH=x64|x86               (default: x64)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROFILE="debug"
DOTNET_TFM="${DOTNET_TFM:-net40}"
DOTNET_ARCH="${DOTNET_ARCH:-x64}"
MONO_VERSION="${WINE_MONO_VERSION:-6.0.0}"
BOOTSTRAP_STAMP_NAME=".volvoxgrid_wine_bootstrap_v1"
LOG_HASHES="${VOLVOXGRID_LOG_HASHES:-0}"

normalize_tfm_for_path() {
    local tfm="$1"
    tfm="${tfm//\//_}"
    tfm="${tfm//:/_}"
    printf '%s\n' "$tfm"
}

normalize_arch() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

resolve_stage_dir() {
    local profile="$1"
    local tfm="$2"
    local arch="$3"
    local base=""
    if [ "$tfm" = "net40" ]; then
        base="$ROOT_DIR/target/dotnet/winforms_${profile}"
    else
        base="$ROOT_DIR/target/dotnet/winforms_${profile}_$(normalize_tfm_for_path "$tfm")"
    fi

    if [ "$arch" != "x64" ]; then
        base="${base}_${arch}"
    fi

    printf '%s\n' "$base"
}

for arg in "$@"; do
    case "$arg" in
        release|--release)
            PROFILE="release"
            ;;
    esac
done

DOTNET_ARCH="$(normalize_arch "$DOTNET_ARCH")"
case "$DOTNET_ARCH" in
    x64|amd64)
        DOTNET_ARCH="x64"
        ;;
    x86|i386|i686)
        DOTNET_ARCH="x86"
        ;;
    *)
        echo "ERROR: unsupported DOTNET_ARCH='$DOTNET_ARCH'. Use x64 or x86." >&2
        exit 1
        ;;
esac

STAGE_DIR="$(resolve_stage_dir "$PROFILE" "$DOTNET_TFM" "$DOTNET_ARCH")"
ENTRY_NAME="VolvoxGrid.WinFormsSample.exe"
if [ "$DOTNET_TFM" != "net40" ]; then
    ENTRY_NAME="VolvoxGrid.WinFormsSample.dll"
fi

if [ ! -f "$STAGE_DIR/$ENTRY_NAME" ]; then
    DOTNET_TFM="$DOTNET_TFM" DOTNET_ARCH="$DOTNET_ARCH" "$SCRIPT_DIR/build_dotnet.sh" "$PROFILE"
fi

require_stage_file() {
    local name="$1"
    local path="$STAGE_DIR/$name"
    if [ ! -f "$path" ]; then
        echo "ERROR: missing staged artifact: $path" >&2
        exit 1
    fi
}

to_wine_path() {
    local abs_path
    abs_path="$(realpath "$1")"
    abs_path="${abs_path//\//\\}"
    printf 'Z:%s\n' "$abs_path"
}

prepare_wine_prefix() {
    local stamp_path="$WINEPREFIX/$BOOTSTRAP_STAMP_NAME"

    if [ -f "$stamp_path" ] && [ -d "$WINEPREFIX/drive_c/windows/mono/mono-2.0" ]; then
        return
    fi

    echo "Preparing Wine prefix (first run for this prefix)..."
    mkdir -p "$(dirname "$WINEPREFIX")"
    wineboot -u >/dev/null 2>&1 || true

    if [ ! -d "$WINEPREFIX/drive_c/windows/mono/mono-2.0" ]; then
        local mono_msi="/tmp/wine-mono-${MONO_VERSION}-x86.msi"
        if [ ! -f "$mono_msi" ]; then
            if ! command -v curl >/dev/null 2>&1; then
                echo "ERROR: curl is required to download Wine Mono (${MONO_VERSION})." >&2
                exit 1
            fi

            echo "Downloading Wine Mono ${MONO_VERSION}..."
            curl -fsSL "https://dl.winehq.org/wine/wine-mono/${MONO_VERSION}/wine-mono-${MONO_VERSION}-x86.msi" -o "$mono_msi"
        fi

        echo "Installing Wine Mono ${MONO_VERSION} into $WINEPREFIX ..."
        wine msiexec /i "$(to_wine_path "$mono_msi")" /qn /norestart
    fi

    local host_font=""
    local font_candidates=(
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        "/usr/share/fonts/dejavu/DejaVuSans.ttf"
    )

    for candidate in "${font_candidates[@]}"; do
        if [ -f "$candidate" ]; then
            host_font="$candidate"
            break
        fi
    done

    if [ -z "$host_font" ]; then
        echo "WARNING: DejaVuSans.ttf was not found on host; WinForms may fail without fallback fonts." >&2
        return
    fi

    local fonts_dir="$WINEPREFIX/drive_c/windows/Fonts"
    mkdir -p "$fonts_dir"
    cp -f "$host_font" "$fonts_dir/dejavusans.ttf"
    cp -f "$host_font" "$fonts_dir/arial.ttf"

    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "DejaVu Sans (TrueType)" /t REG_SZ /d dejavusans.ttf /f >/dev/null 2>&1 || true
    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Arial (TrueType)" /t REG_SZ /d arial.ttf /f >/dev/null 2>&1 || true
    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Arial" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Tahoma" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Microsoft Sans Serif" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Sans Serif" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Shell Dlg" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
    wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Shell Dlg 2" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true

    mkdir -p "$WINEPREFIX"
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$stamp_path"
}

is_windows_host() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        MINGW*|MSYS*|CYGWIN*)
            return 0
            ;;
    esac

    [ "${OS:-}" = "Windows_NT" ]
}

rm -f "$STAGE_DIR/VolvoxGrid.WinFormsSample.log"

if [ "$DOTNET_TFM" = "net40" ]; then
    if [ "$DOTNET_ARCH" = "x86" ]; then
        export WINEPREFIX="${WINEPREFIX:-$ROOT_DIR/target/dotnet/wineprefix_x86}"
        export WINEARCH="${WINEARCH:-win32}"
    else
        export WINEPREFIX="${WINEPREFIX:-$ROOT_DIR/target/dotnet/wineprefix}"
        export WINEARCH="${WINEARCH:-win64}"
    fi

    require_stage_file "VolvoxGrid.WinFormsSample.exe"
    require_stage_file "VolvoxGrid.DotNet.dll"
    require_stage_file "volvoxgrid_plugin.dll"

    echo "Running sample: $STAGE_DIR/VolvoxGrid.WinFormsSample.exe"
    echo "Arch=$DOTNET_ARCH"
    echo "WINEPREFIX=$WINEPREFIX"
    prepare_wine_prefix

    echo "Using staged binaries:"
    for name in \
        "VolvoxGrid.WinFormsSample.exe" \
        "VolvoxGrid.DotNet.dll" \
        "volvoxgrid_plugin.dll"
    do
        path="$STAGE_DIR/$name"
        wine_path="$(to_wine_path "$path")"
        size_bytes="$(wc -c < "$path" | tr -d '[:space:]')"
        if [ "$LOG_HASHES" = "1" ] && command -v sha256sum >/dev/null 2>&1; then
            sha256="$(sha256sum "$path" | awk '{print $1}')"
            echo "  $name"
            echo "    path: $path"
            echo "    wine: $wine_path"
            echo "    size: ${size_bytes} bytes"
            echo "    sha256: $sha256"
        else
            echo "  $name"
            echo "    path: $path"
            echo "    wine: $wine_path"
            echo "    size: ${size_bytes} bytes"
        fi
    done

    cd "$STAGE_DIR"
    if [ "${VOLVOXGRID_SMOKE_MODE:-0}" = "1" ]; then
        smoke_timeout="${VOLVOXGRID_SMOKE_TIMEOUT_SEC:-90}"
        smoke_log="$STAGE_DIR/VolvoxGrid.WinFormsSample.log"
        echo "Smoke mode enabled (timeout=${smoke_timeout}s). Waiting for SMOKE RESULT marker..."
        wine VolvoxGrid.WinFormsSample.exe &
        wine_pid=$!
        deadline=$((SECONDS + smoke_timeout))
        smoke_result=""

        while [ "$SECONDS" -lt "$deadline" ]; do
            if [ -f "$smoke_log" ]; then
                if grep -q "SMOKE RESULT: PASS" "$smoke_log"; then
                    smoke_result="pass"
                    break
                fi

                if grep -q "SMOKE RESULT: FAIL" "$smoke_log"; then
                    smoke_result="fail"
                    break
                fi
            fi

            sleep 1
        done

        if kill -0 "$wine_pid" >/dev/null 2>&1; then
            kill "$wine_pid" >/dev/null 2>&1 || true
            wait "$wine_pid" >/dev/null 2>&1 || true
        fi

        case "$smoke_result" in
            pass)
                echo "Smoke result: PASS"
                exit 0
                ;;
            fail)
                echo "Smoke result: FAIL"
                exit 1
                ;;
            *)
                echo "ERROR: Smoke timeout/no result marker in log: $smoke_log" >&2
                exit 2
                ;;
        esac
    fi

    wine VolvoxGrid.WinFormsSample.exe
    exit 0
fi

require_stage_file "VolvoxGrid.WinFormsSample.dll"
require_stage_file "VolvoxGrid.WinFormsSample.deps.json"
require_stage_file "VolvoxGrid.WinFormsSample.runtimeconfig.json"
require_stage_file "VolvoxGrid.DotNet.dll"
require_stage_file "volvoxgrid_plugin.dll"

if [[ "$DOTNET_TFM" == *"-windows"* ]] && ! is_windows_host; then
    echo "ERROR: DOTNET_TFM=$DOTNET_TFM requires Windows runtime."
    echo "Build artifacts are staged at: $STAGE_DIR"
    echo "Run on Windows with:"
    echo "  dotnet \"$STAGE_DIR/VolvoxGrid.WinFormsSample.dll\""
    exit 1
fi

if ! command -v dotnet >/dev/null 2>&1; then
    echo "ERROR: dotnet CLI not found in PATH." >&2
    exit 1
fi

echo "Running sample: $STAGE_DIR/VolvoxGrid.WinFormsSample.dll"
echo "TFM=$DOTNET_TFM"
echo "Using staged binaries:"
for name in \
    "VolvoxGrid.WinFormsSample.dll" \
    "VolvoxGrid.WinFormsSample.deps.json" \
    "VolvoxGrid.WinFormsSample.runtimeconfig.json" \
    "VolvoxGrid.DotNet.dll" \
    "volvoxgrid_plugin.dll"
do
    path="$STAGE_DIR/$name"
    size_bytes="$(wc -c < "$path" | tr -d '[:space:]')"
    if [ "$LOG_HASHES" = "1" ] && command -v sha256sum >/dev/null 2>&1; then
        sha256="$(sha256sum "$path" | awk '{print $1}')"
        echo "  $name"
        echo "    path: $path"
        echo "    size: ${size_bytes} bytes"
        echo "    sha256: $sha256"
    else
        echo "  $name"
        echo "    path: $path"
        echo "    size: ${size_bytes} bytes"
    fi
done

cd "$STAGE_DIR"
dotnet VolvoxGrid.WinFormsSample.dll
