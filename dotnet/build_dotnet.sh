#!/bin/bash
# build_dotnet.sh — Build VolvoxGrid .NET samples for WinForms/Wine, controller console, or TUI.
#
# Usage:
#   ./dotnet/build_dotnet.sh [release]
#
# Environment:
#   DOTNET_TFM=net40|net8.0|net8.0-windows   (default: net40)
#   DOTNET_ARCH=x64|x86                      (default: x64, WinForms builds only)
#   DOTNET_SAMPLE=auto|winforms|console|tui  (default: auto)
#
# Produces:
#   ${CARGO_TARGET_DIR:-target}/<windows-target-triple>/{debug|release}/volvoxgrid_plugin.dll
#   ${CARGO_TARGET_DIR:-target}/{debug|release}/libvolvoxgrid_plugin.{so|dylib}
#   target/dotnet/{winforms|console}_{debug|release}[_<tfm>]/*

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CARGO_ARTIFACT_ROOT="${CARGO_TARGET_DIR:-$ROOT_DIR/target}"

PROFILE="debug"
DOTNET_CFG="Debug"
CARGO_FLAGS=""
TARGET_DIR="debug"
TARGET_TFM="${DOTNET_TFM:-net40}"
TARGET_ARCH="${DOTNET_ARCH:-x64}"
TARGET_SAMPLE="${DOTNET_SAMPLE:-}"
unset DOTNET_TFM DOTNET_ARCH
PLUGIN_FEATURES="${VOLVOXGRID_DOTNET_PLUGIN_FEATURES:-gpu}"
PLUGIN_FEATURE_ARGS=()
RUST_WINDOWS_TARGET=""
DOTNET_PLATFORM_TARGET=""
MSBUILD_ARCH_ROOT="default"

normalize_tfm_for_path() {
    local tfm="$1"
    tfm="${tfm//\//_}"
    tfm="${tfm//:/_}"
    printf '%s\n' "$tfm"
}

normalize_arch() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

sample_kind_for_tfm() {
    local tfm="$1"
    if [ "$tfm" = "net40" ] || [[ "$tfm" == *"-windows"* ]]; then
        printf 'winforms\n'
    else
        printf 'console\n'
    fi
}

sample_project_for_kind() {
    local kind="$1"
    case "$kind" in
        winforms)
            printf '%s\n' "$ROOT_DIR/dotnet/examples/winforms/VolvoxGrid.WinFormsSample.csproj"
            ;;
        console)
            printf '%s\n' "$ROOT_DIR/dotnet/examples/console/VolvoxGrid.ConsoleSample.csproj"
            ;;
        tui)
            printf '%s\n' "$ROOT_DIR/dotnet/examples/tui/VolvoxGrid.TuiSample.csproj"
            ;;
        *)
            echo "ERROR: unknown sample kind '$kind'" >&2
            exit 1
            ;;
    esac
}

sample_basename_for_kind() {
    local kind="$1"
    case "$kind" in
        winforms)
            printf 'VolvoxGrid.WinFormsSample\n'
            ;;
        console)
            printf 'VolvoxGrid.ConsoleSample\n'
            ;;
        tui)
            printf 'VolvoxGrid.TuiSample\n'
            ;;
        *)
            echo "ERROR: unknown sample kind '$kind'" >&2
            exit 1
            ;;
    esac
}

native_plugin_basename() {
    local tfm="$1"
    if [ "$tfm" = "net40" ] || [[ "$tfm" == *"-windows"* ]]; then
        printf 'volvoxgrid_plugin.dll\n'
        return
    fi

    case "$(uname -s 2>/dev/null || echo unknown)" in
        Darwin)
            printf 'libvolvoxgrid_plugin.dylib\n'
            ;;
        MINGW*|MSYS*|CYGWIN*)
            printf 'volvoxgrid_plugin.dll\n'
            ;;
        *)
            printf 'libvolvoxgrid_plugin.so\n'
            ;;
    esac
}

has_windowsdesktop_sdk() {
    local base_path=""
    if ! command -v dotnet >/dev/null 2>&1; then
        return 1
    fi

    base_path="$(dotnet --info 2>/dev/null | awk -F: '/Base Path/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}')"
    if [ -z "$base_path" ]; then
        return 1
    fi

    [ -f "${base_path%/}/Sdks/Microsoft.NET.Sdk.WindowsDesktop/targets/Microsoft.NET.Sdk.WindowsDesktop.targets" ]
}

restore_sample_project() {
    if [ "$TARGET_TFM" = "net40" ]; then
        OFFLINE_NUPKG="${HOME:-}/.nuget/packages/microsoft.netframework.referenceassemblies.net40/1.0.3/microsoft.netframework.referenceassemblies.net40.1.0.3.nupkg"
        if [ -f "$OFFLINE_NUPKG" ]; then
            OFFLINE_FEED="$ROOT_DIR/target/dotnet/nuget-offline"
            OFFLINE_CONFIG="$OFFLINE_FEED/nuget.config"
            mkdir -p "$OFFLINE_FEED"
            cp -f "$OFFLINE_NUPKG" "$OFFLINE_FEED/"
            cat > "$OFFLINE_CONFIG" <<EOF_OFFLINE_NUGET
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="offline" value="$OFFLINE_FEED" />
  </packageSources>
</configuration>
EOF_OFFLINE_NUGET
            if [ "${#DOTNET_PROPS[@]}" -gt 0 ]; then
                dotnet restore "$SAMPLE_PROJECT" "${DOTNET_PROPS[@]}" --configfile "$OFFLINE_CONFIG"
            else
                dotnet restore "$SAMPLE_PROJECT" --configfile "$OFFLINE_CONFIG"
            fi
            return
        fi
    fi

    if [ "${#DOTNET_PROPS[@]}" -gt 0 ]; then
        dotnet restore "$SAMPLE_PROJECT" "${DOTNET_PROPS[@]}"
    else
        dotnet restore "$SAMPLE_PROJECT"
    fi
}

resolve_stage_dir() {
    local profile="$1"
    local tfm="$2"
    local arch="$3"
    local sample_kind="$4"
    local base=""

    case "$sample_kind" in
        winforms)
            if [ "$tfm" = "net40" ]; then
                base="$ROOT_DIR/target/dotnet/winforms_${profile}"
            else
                base="$ROOT_DIR/target/dotnet/winforms_${profile}_$(normalize_tfm_for_path "$tfm")"
            fi
            if [ "$arch" != "x64" ]; then
                base="${base}_${arch}"
            fi
            ;;
        console)
            base="$ROOT_DIR/target/dotnet/console_${profile}_$(normalize_tfm_for_path "$tfm")"
            ;;
        tui)
            base="$ROOT_DIR/target/dotnet/tui_${profile}_$(normalize_tfm_for_path "$tfm")"
            ;;
        *)
            echo "ERROR: unknown sample kind '$sample_kind'" >&2
            exit 1
            ;;
    esac

    printf '%s\n' "$base"
}

copy_required_artifact() {
    local src="$1"
    if [ ! -f "$src" ]; then
        echo "ERROR: missing build artifact: $src" >&2
        exit 1
    fi
    cp -f "$src" "$STAGE_DIR/"
}

if [ -n "$PLUGIN_FEATURES" ]; then
    PLUGIN_FEATURE_ARGS=(--features "$PLUGIN_FEATURES")
fi

TARGET_ARCH="$(normalize_arch "$TARGET_ARCH")"
case "$TARGET_ARCH" in
    x64|amd64)
        TARGET_ARCH="x64"
        RUST_WINDOWS_TARGET="x86_64-pc-windows-gnu"
        ;;
    x86|i386|i686)
        TARGET_ARCH="x86"
        RUST_WINDOWS_TARGET="i686-pc-windows-gnu"
        ;;
    *)
        echo "ERROR: unsupported DOTNET_ARCH='$TARGET_ARCH'. Use x64 or x86." >&2
        exit 1
        ;;
esac

while [ "$#" -gt 0 ]; do
    case "$1" in
        release|--release)
            PROFILE="release"
            DOTNET_CFG="Release"
            CARGO_FLAGS="--release"
            TARGET_DIR="release"
            shift
            ;;
        --tfm)
            TARGET_TFM="${2:-}"
            if [ -z "$TARGET_TFM" ]; then
                echo "ERROR: --tfm requires a value." >&2
                exit 1
            fi
            shift 2
            ;;
        --arch)
            TARGET_ARCH="${2:-}"
            if [ -z "$TARGET_ARCH" ]; then
                echo "ERROR: --arch requires a value." >&2
                exit 1
            fi
            shift 2
            ;;
        --sample)
            TARGET_SAMPLE="${2:-}"
            if [ -z "$TARGET_SAMPLE" ]; then
                echo "ERROR: --sample requires a value." >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "ERROR: unknown argument '$1'." >&2
            exit 1
            ;;
    esac
done

if [ -z "$TARGET_SAMPLE" ] || [ "$TARGET_SAMPLE" = "auto" ]; then
    SAMPLE_KIND="$(sample_kind_for_tfm "$TARGET_TFM")"
else
    SAMPLE_KIND="$TARGET_SAMPLE"
fi
SAMPLE_PROJECT="$(sample_project_for_kind "$SAMPLE_KIND")"
SAMPLE_BASENAME="$(sample_basename_for_kind "$SAMPLE_KIND")"
PLUGIN_BASENAME="$(native_plugin_basename "$TARGET_TFM")"

if [ "$SAMPLE_KIND" = "tui" ] && [ "$TARGET_TFM" != "net8.0" ]; then
    echo "ERROR: the TUI sample requires DOTNET_TFM=net8.0." >&2
    exit 1
fi

if [ "$SAMPLE_KIND" = "winforms" ]; then
    DOTNET_PLATFORM_TARGET="$TARGET_ARCH"
    MSBUILD_ARCH_ROOT="$TARGET_ARCH"
fi

echo "=== VolvoxGrid .NET Build (${PROFILE}, ${TARGET_TFM}, ${TARGET_ARCH}, ${SAMPLE_KIND}) ==="

if [ "$SAMPLE_KIND" = "winforms" ]; then
    echo "[plugin] cargo build --target ${RUST_WINDOWS_TARGET} ${CARGO_FLAGS} ${PLUGIN_FEATURE_ARGS[*]}"
    cargo build --manifest-path "$ROOT_DIR/plugin/Cargo.toml" --target "$RUST_WINDOWS_TARGET" -p volvoxgrid-plugin $CARGO_FLAGS "${PLUGIN_FEATURE_ARGS[@]}"
    PLUGIN_ARTIFACT="$CARGO_ARTIFACT_ROOT/${RUST_WINDOWS_TARGET}/${TARGET_DIR}/volvoxgrid_plugin.dll"
else
    echo "[plugin] cargo build ${CARGO_FLAGS} ${PLUGIN_FEATURE_ARGS[*]}"
    cargo build --manifest-path "$ROOT_DIR/plugin/Cargo.toml" -p volvoxgrid-plugin $CARGO_FLAGS "${PLUGIN_FEATURE_ARGS[@]}"
    PLUGIN_ARTIFACT="$CARGO_ARTIFACT_ROOT/${TARGET_DIR}/${PLUGIN_BASENAME}"
fi

DOTNET_PROPS=()

if [ -n "$DOTNET_PLATFORM_TARGET" ]; then
    DOTNET_PROPS+=(-p:PlatformTarget="$DOTNET_PLATFORM_TARGET")
fi

if [[ "$TARGET_TFM" == *"-windows"* ]]; then
    DOTNET_PROPS+=(-p:IncludeWindowsDesktopTarget=true)
    DOTNET_PROPS+=(-p:EnableWindowsTargeting=true)
fi

if [ "$TARGET_TFM" = "net40" ]; then
    DOTNET_PROPS+=(-p:VolvoxGridLegacyOnly=true)
fi

if [[ "$TARGET_TFM" == *"-windows"* ]] && ! has_windowsdesktop_sdk; then
    echo "ERROR: DOTNET_TFM=$TARGET_TFM requires Microsoft.NET.Sdk.WindowsDesktop, but it is not installed in this dotnet SDK." >&2
    echo "This is expected on most Linux dotnet installations." >&2
    echo "Use one of these paths:" >&2
    echo "  1) Build/run net40 on Linux: make dotnet-run-release" >&2
    echo "  2) Build/run net8.0 on Linux: make dotnet-run-release DOTNET_TFM=net8.0" >&2
    echo "  3) Build/run $TARGET_TFM on Windows with .NET 8 SDK (Windows Desktop support)." >&2
    exit 1
fi

if [ "$TARGET_TFM" = "net40" ]; then
    NET40_REF_MSCORLIB="${HOME:-}/.nuget/packages/microsoft.netframework.referenceassemblies.net40/1.0.3/build/.NETFramework/v4.0/mscorlib.dll"
    if [ ! -f "$NET40_REF_MSCORLIB" ]; then
        echo "[dotnet] net40 reference assemblies not found in NuGet cache; restoring first"
        restore_sample_project
    fi
fi

#
# MSBuild can flake in multi-node project-reference discovery immediately after
# the cargo plugin build in this wrapper flow. Force single-node mode here so
# `make dotnet-*` stays deterministic across console/TUI samples.
DOTNET_BUILD_ARGS=(-m:1)

echo "[dotnet] build sample (${DOTNET_CFG}, ${TARGET_TFM}, ${DOTNET_PLATFORM_TARGET:-default}, --no-restore, ${DOTNET_BUILD_ARGS[*]})"
if [ "${#DOTNET_PROPS[@]}" -gt 0 ]; then
    BUILD_CMD=(dotnet build "$SAMPLE_PROJECT" -c "$DOTNET_CFG" -f "$TARGET_TFM" "${DOTNET_BUILD_ARGS[@]}" "${DOTNET_PROPS[@]}" --no-restore)
else
    BUILD_CMD=(dotnet build "$SAMPLE_PROJECT" -c "$DOTNET_CFG" -f "$TARGET_TFM" "${DOTNET_BUILD_ARGS[@]}" --no-restore)
fi
if ! "${BUILD_CMD[@]}"; then
    echo "[dotnet] no-restore build failed; attempting restore + rebuild"
    restore_sample_project
    "${BUILD_CMD[@]}"
fi

MSBUILD_BIN_ROOT="$ROOT_DIR/target/dotnet/msbuild/bin/${MSBUILD_ARCH_ROOT}"
MSBUILD_OBJ_ROOT="$ROOT_DIR/target/dotnet/msbuild/obj/${MSBUILD_ARCH_ROOT}"
SAMPLE_DIR="$MSBUILD_BIN_ROOT/${SAMPLE_BASENAME}/${DOTNET_CFG}/${TARGET_TFM}"
SAMPLE_OBJ_DIR="$MSBUILD_OBJ_ROOT/${SAMPLE_BASENAME}/${DOTNET_CFG}/${TARGET_TFM}"
WRAPPER_OBJ_DIR="$MSBUILD_OBJ_ROOT/VolvoxGrid.DotNet/${DOTNET_CFG}/${TARGET_TFM}"
STAGE_DIR="$(resolve_stage_dir "$PROFILE" "$TARGET_TFM" "$TARGET_ARCH" "$SAMPLE_KIND")"

if [ ! -d "$SAMPLE_DIR" ]; then
    echo "ERROR: sample output directory not found: $SAMPLE_DIR" >&2
    exit 1
fi

mkdir -p "$STAGE_DIR"

if [ ! -f "$PLUGIN_ARTIFACT" ]; then
    echo "ERROR: missing build artifact: $PLUGIN_ARTIFACT" >&2
    exit 1
fi

cp -f "$PLUGIN_ARTIFACT" "$STAGE_DIR/$PLUGIN_BASENAME"

if [ "$TARGET_TFM" = "net40" ]; then
    # net40 authoritative compile outputs are under obj/, while bin/ may keep stale arch copies.
    copy_required_artifact "$SAMPLE_OBJ_DIR/${SAMPLE_BASENAME}.exe"
    copy_required_artifact "$SAMPLE_DIR/${SAMPLE_BASENAME}.exe.config"
    copy_required_artifact "$WRAPPER_OBJ_DIR/VolvoxGrid.DotNet.dll"
    SAMPLE_ENTRY="$SAMPLE_OBJ_DIR/${SAMPLE_BASENAME}.exe"
else
    find "$SAMPLE_DIR" -maxdepth 1 -type f -exec cp -f {} "$STAGE_DIR/" \;
    SAMPLE_ENTRY="$SAMPLE_DIR/${SAMPLE_BASENAME}.dll"
fi

echo ""
echo "=== Build Complete ==="
echo "TFM:    $TARGET_TFM"
echo "Arch:   ${DOTNET_PLATFORM_TARGET:-default}"
echo "Plugin: $PLUGIN_ARTIFACT"
echo "Sample: $SAMPLE_ENTRY"
echo "Stage:  $STAGE_DIR"
