#!/bin/bash
# run_demo.sh -- Launch the classic VolvoxGrid ActiveX demo under Wine.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="$(pwd)/$SCRIPT_PATH"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PROFILE="debug"
if [[ "${1:-}" == "release" || "${1:-}" == "--release" ]]; then
    PROFILE="release"
fi

ACTIVEX_ARCH="${ACTIVEX_ARCH:-x86_64}"
XVFB_SCREEN="${XVFB_SCREEN:-1600x900x24}"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        i686|x86|i386) printf 'i686\n' ;;
        x86_64|amd64|x64) printf 'x86_64\n' ;;
        *) return 1 ;;
    esac
}

prepare_wine_prefix() {
    local stamp_path="$WINEPREFIX/.volvoxgrid_activex_demo_bootstrap_v4"
    local host_font=""
    local cjk_src=""
    local fonts_dir=""
    local candidate=""

    if [[ -f "$stamp_path" ]]; then
        return
    fi

    echo "Preparing Wine prefix: $WINEPREFIX"
    mkdir -p "$WINEPREFIX"
    wineboot -u >/dev/null 2>&1 || true
    fonts_dir="$WINEPREFIX/drive_c/windows/Fonts"
    mkdir -p "$fonts_dir"

    for candidate in \
        /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf \
        /usr/share/fonts/dejavu/DejaVuSans.ttf
    do
        if [[ -f "$candidate" ]]; then
            host_font="$candidate"
            break
        fi
    done

    if [[ -n "$host_font" ]]; then
        cp -f "$host_font" "$fonts_dir/dejavusans.ttf"
        cp -f "$host_font" "$fonts_dir/arial.ttf"
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "DejaVu Sans (TrueType)" /t REG_SZ /d dejavusans.ttf /f >/dev/null 2>&1 || true
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Arial (TrueType)" /t REG_SZ /d arial.ttf /f >/dev/null 2>&1 || true
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Arial" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Tahoma" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Sans Serif" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "Microsoft Sans Serif" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Shell Dlg" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
        wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes" /v "MS Shell Dlg 2" /t REG_SZ /d "DejaVu Sans" /f >/dev/null 2>&1 || true
    else
        echo "WARNING: DejaVuSans.ttf not found on host; classic font fallback may be rough." >&2
    fi

    if [[ "$PROFILE" == "release" ]]; then
        for candidate in \
            /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc \
            /usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc \
            /usr/share/fonts/google-noto-cjk/NotoSansCJK-Regular.ttc
        do
            if [[ -f "$candidate" ]]; then
                cjk_src="$candidate"
                break
            fi
        done

        if [[ -n "$cjk_src" ]]; then
            cp -f "$cjk_src" "$fonts_dir/NotoSansCJK-Regular.ttc"
            wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Noto Sans CJK HK (TrueType)" /t REG_SZ /d NotoSansCJK-Regular.ttc /f >/dev/null 2>&1 || true
            wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Noto Sans CJK JP (TrueType)" /t REG_SZ /d NotoSansCJK-Regular.ttc /f >/dev/null 2>&1 || true
            wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Noto Sans CJK KR (TrueType)" /t REG_SZ /d NotoSansCJK-Regular.ttc /f >/dev/null 2>&1 || true
            wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Noto Sans CJK SC (TrueType)" /t REG_SZ /d NotoSansCJK-Regular.ttc /f >/dev/null 2>&1 || true
            wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts" /v "Noto Sans CJK TC (TrueType)" /t REG_SZ /d NotoSansCJK-Regular.ttc /f >/dev/null 2>&1 || true
        fi
    fi

    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$stamp_path"
}

ACTIVEX_ARCH="$(normalize_arch "$ACTIVEX_ARCH")" || {
    echo "ERROR: unsupported ACTIVEX_ARCH='$ACTIVEX_ARCH'. Use i686 or x86_64." >&2
    exit 1
}

if [[ -z "${DISPLAY:-}" && "${RUN_ACTIVEX_DEMO_XVFB_WRAPPED:-0}" != "1" ]]; then
    command -v xvfb-run >/dev/null 2>&1 || {
        echo "ERROR: DISPLAY is not set and xvfb-run is not installed." >&2
        exit 1
    }
    export RUN_ACTIVEX_DEMO_XVFB_WRAPPED=1
    exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN}" "$SCRIPT_PATH" "$@"
fi

OCX_PATH="$ROOT_DIR/target/ocx/VolvoxGrid_${ACTIVEX_ARCH}.ocx"
HOST_EXE="$ROOT_DIR/target/ocx/volvoxgrid_demo_host_${ACTIVEX_ARCH}.exe"

if [[ ! -f "$OCX_PATH" || ! -f "$HOST_EXE" ]]; then
    echo "Build artifacts missing for $ACTIVEX_ARCH; rebuilding..."
    (
        cd "$SCRIPT_DIR"
        if [[ "$PROFILE" == "release" ]]; then
            ./build_ocx.sh release
        else
            ./build_ocx.sh
        fi
    )
fi

if [[ ! -f "$OCX_PATH" ]]; then
    echo "ERROR: missing OCX artifact: $OCX_PATH" >&2
    exit 1
fi
if [[ ! -f "$HOST_EXE" ]]; then
    echo "ERROR: missing demo host artifact: $HOST_EXE" >&2
    exit 1
fi

if [[ "$ACTIVEX_ARCH" == "i686" ]]; then
    export WINEARCH="${WINEARCH:-win32}"
    export WINEPREFIX="${WINEPREFIX:-$ROOT_DIR/target/ocx/wineprefix_i686}"
else
    export WINEARCH="${WINEARCH:-win64}"
    export WINEPREFIX="${WINEPREFIX:-$ROOT_DIR/target/ocx/wineprefix_x86_64}"
fi

command -v wine >/dev/null 2>&1 || {
    echo "ERROR: wine not found" >&2
    exit 1
}

WINEDEBUG=-all wine reg add "HKCU\\Software\\Wine\\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f >/dev/null 2>&1 || true
WINEDEBUG=-all wine reg add "HKCU\\Software\\Wine\\WineDbg" /v ShowAssertDialog /t REG_DWORD /d 0 /f >/dev/null 2>&1 || true

prepare_wine_prefix

echo "Registering $OCX_PATH"
WINEDEBUG=-all wine regsvr32 /s "$(realpath "$OCX_PATH")"

echo "Launching classic ActiveX demo"
echo "  profile: $PROFILE"
echo "  arch:    $ACTIVEX_ARCH"
echo "  prefix:  $WINEPREFIX"

cd "$(dirname "$HOST_EXE")"
if [[ "$PROFILE" == "release" && -f "$WINEPREFIX/drive_c/windows/Fonts/NotoSansCJK-Regular.ttc" ]]; then
    exec env WINEDEBUG=-all wine "./$(basename "$HOST_EXE")" --font-name "Noto Sans CJK KR"
fi
exec env WINEDEBUG=-all wine "./$(basename "$HOST_EXE")"
