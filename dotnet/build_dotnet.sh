#!/bin/bash
# build_dotnet.sh — Build VolvoxGrid .NET wrapper + sample artifacts for Wine/Windows.
#
# Usage:
#   ./dotnet/build_dotnet.sh [release]
#
# Environment:
#   DOTNET_TFM=net40|net8.0-windows   (default: net40)
#   DOTNET_ARCH=x64|x86               (default: x64)
#
# Produces:
#   target/<windows-target-triple>/{debug|release}/volvoxgrid_plugin.dll
#   target/dotnet/winforms_{debug|release}[/_<tfm>]/*

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PROFILE="debug"
DOTNET_CFG="Debug"
CARGO_FLAGS=""
TARGET_DIR="debug"
DOTNET_TFM="${DOTNET_TFM:-net40}"
DOTNET_ARCH="${DOTNET_ARCH:-x64}"
PLUGIN_FEATURES="${VOLVOXGRID_DOTNET_PLUGIN_FEATURES:-gpu}"
PLUGIN_FEATURE_ARGS=()
RUST_WINDOWS_TARGET=""
DOTNET_PLATFORM_TARGET=""

normalize_tfm_for_path() {
    local tfm="$1"
    tfm="${tfm//\//_}"
    tfm="${tfm//:/_}"
    printf '%s\n' "$tfm"
}

normalize_arch() {
    printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
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
    if [ "$DOTNET_TFM" = "net40" ]; then
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
            dotnet restore "$SAMPLE_PROJECT" "${DOTNET_PROPS[@]}" --configfile "$OFFLINE_CONFIG"
            return
        fi
    fi

    dotnet restore "$SAMPLE_PROJECT" "${DOTNET_PROPS[@]}"
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

DOTNET_ARCH="$(normalize_arch "$DOTNET_ARCH")"
case "$DOTNET_ARCH" in
    x64|amd64)
        DOTNET_ARCH="x64"
        DOTNET_PLATFORM_TARGET="x64"
        RUST_WINDOWS_TARGET="x86_64-pc-windows-gnu"
        ;;
    x86|i386|i686)
        DOTNET_ARCH="x86"
        DOTNET_PLATFORM_TARGET="x86"
        RUST_WINDOWS_TARGET="i686-pc-windows-gnu"
        ;;
    *)
        echo "ERROR: unsupported DOTNET_ARCH='$DOTNET_ARCH'. Use x64 or x86." >&2
        exit 1
        ;;
esac

for arg in "$@"; do
    case "$arg" in
        release|--release)
            PROFILE="release"
            DOTNET_CFG="Release"
            CARGO_FLAGS="--release"
            TARGET_DIR="release"
            ;;
    esac
done

echo "=== VolvoxGrid .NET Build (${PROFILE}, ${DOTNET_TFM}, ${DOTNET_ARCH}) ==="

echo "[plugin] cargo build --target ${RUST_WINDOWS_TARGET} ${CARGO_FLAGS} ${PLUGIN_FEATURE_ARGS[*]}"
cargo build --manifest-path "$ROOT_DIR/plugin/Cargo.toml" --target "$RUST_WINDOWS_TARGET" -p volvoxgrid-plugin $CARGO_FLAGS "${PLUGIN_FEATURE_ARGS[@]}"

SAMPLE_PROJECT="$ROOT_DIR/dotnet/examples/winforms/VolvoxGrid.WinFormsSample.csproj"
DOTNET_PROPS=(
    -p:PlatformTarget="$DOTNET_PLATFORM_TARGET"
    -p:EnableWindowsTargeting=true
    -p:TargetFramework="$DOTNET_TFM"
)

if [ "$DOTNET_TFM" = "net40" ]; then
    DOTNET_PROPS+=(-p:VolvoxGridLegacyOnly=true)
fi

if [[ "$DOTNET_TFM" == *"-windows"* ]] && ! has_windowsdesktop_sdk; then
    echo "ERROR: DOTNET_TFM=$DOTNET_TFM requires Microsoft.NET.Sdk.WindowsDesktop, but it is not installed in this dotnet SDK." >&2
    echo "This is expected on most Linux dotnet installations." >&2
    echo "Use one of these paths:" >&2
    echo "  1) Build/run net40 on Linux: make dotnet-run-release" >&2
    echo "  2) Build/run $DOTNET_TFM on Windows with .NET 8 SDK (Windows Desktop support)." >&2
    exit 1
fi

if [ "$DOTNET_TFM" = "net40" ]; then
    NET40_REF_MSCORLIB="${HOME:-}/.nuget/packages/microsoft.netframework.referenceassemblies.net40/1.0.3/build/.NETFramework/v4.0/mscorlib.dll"
    if [ ! -f "$NET40_REF_MSCORLIB" ]; then
        echo "[dotnet] net40 reference assemblies not found in NuGet cache; restoring first"
        restore_sample_project
    fi
fi

echo "[dotnet] build sample (${DOTNET_CFG}, ${DOTNET_TFM}, ${DOTNET_PLATFORM_TARGET}, --no-restore)"
if ! dotnet build "$SAMPLE_PROJECT" -c "$DOTNET_CFG" -f "$DOTNET_TFM" "${DOTNET_PROPS[@]}" --no-restore; then
    echo "[dotnet] no-restore build failed; attempting restore + rebuild"
    restore_sample_project
    dotnet build "$SAMPLE_PROJECT" -c "$DOTNET_CFG" -f "$DOTNET_TFM" "${DOTNET_PROPS[@]}" --no-restore
fi

PLUGIN_DLL="$ROOT_DIR/target/${RUST_WINDOWS_TARGET}/${TARGET_DIR}/volvoxgrid_plugin.dll"
MSBUILD_BIN_ROOT="$ROOT_DIR/target/dotnet/msbuild/bin/${DOTNET_ARCH}"
MSBUILD_OBJ_ROOT="$ROOT_DIR/target/dotnet/msbuild/obj/${DOTNET_ARCH}"
SAMPLE_DIR="$MSBUILD_BIN_ROOT/VolvoxGrid.WinFormsSample/${DOTNET_CFG}/${DOTNET_TFM}"
SAMPLE_OBJ_DIR="$MSBUILD_OBJ_ROOT/VolvoxGrid.WinFormsSample/${DOTNET_CFG}/${DOTNET_TFM}"
WRAPPER_OBJ_DIR="$MSBUILD_OBJ_ROOT/VolvoxGrid.DotNet/${DOTNET_CFG}/${DOTNET_TFM}"
STAGE_DIR="$(resolve_stage_dir "$PROFILE" "$DOTNET_TFM" "$DOTNET_ARCH")"

if [ ! -d "$SAMPLE_DIR" ]; then
    echo "ERROR: sample output directory not found: $SAMPLE_DIR" >&2
    exit 1
fi

mkdir -p "$STAGE_DIR"
rm -f "$STAGE_DIR/VolvoxGrid.Common.dll"

if [ ! -f "$PLUGIN_DLL" ]; then
    echo "ERROR: missing build artifact: $PLUGIN_DLL" >&2
    exit 1
fi
cp -f "$PLUGIN_DLL" "$STAGE_DIR/volvoxgrid_plugin.dll"

if [ "$DOTNET_TFM" = "net40" ]; then
    # net40 authoritative compile outputs are under obj/, while bin/ may keep stale arch copies.
    copy_required_artifact "$SAMPLE_OBJ_DIR/VolvoxGrid.WinFormsSample.exe"
    copy_required_artifact "$SAMPLE_DIR/VolvoxGrid.WinFormsSample.exe.config"
    copy_required_artifact "$WRAPPER_OBJ_DIR/VolvoxGrid.DotNet.dll"
    SAMPLE_ENTRY="$SAMPLE_OBJ_DIR/VolvoxGrid.WinFormsSample.exe"
else
    copy_required_artifact "$SAMPLE_DIR/VolvoxGrid.WinFormsSample.dll"
    copy_required_artifact "$SAMPLE_DIR/VolvoxGrid.WinFormsSample.deps.json"
    copy_required_artifact "$SAMPLE_DIR/VolvoxGrid.WinFormsSample.runtimeconfig.json"
    copy_required_artifact "$SAMPLE_DIR/VolvoxGrid.DotNet.dll"
    if [ -f "$SAMPLE_DIR/VolvoxGrid.WinFormsSample.exe" ]; then
        cp -f "$SAMPLE_DIR/VolvoxGrid.WinFormsSample.exe" "$STAGE_DIR/VolvoxGrid.WinFormsSample.exe"
    fi
    SAMPLE_ENTRY="$SAMPLE_DIR/VolvoxGrid.WinFormsSample.dll"
fi

echo ""
echo "=== Build Complete ==="
echo "TFM:    $DOTNET_TFM"
echo "Arch:   $DOTNET_ARCH"
echo "Plugin: $PLUGIN_DLL"
echo "Sample: $SAMPLE_ENTRY"
echo "Stage:  $STAGE_DIR"
