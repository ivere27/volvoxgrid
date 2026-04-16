#!/bin/bash
# Build VolvoxGrid.ocx for Windows using MinGW cross-compiler.
#
# Prerequisites:
#   - Rust cross-compilation targets: i686-pc-windows-gnu, x86_64-pc-windows-gnu
#   - MinGW toolchains: i686-w64-mingw32-gcc, x86_64-w64-mingw32-gcc
#
# Usage:
#   ./build_ocx.sh [release]

set -euo pipefail
cd "$(dirname "$0")"

PROFILE="debug"
CARGO_FLAGS=""
IS_LITE=0
IS_GPU=0

detect_cpu_count() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
        return
    fi
    if command -v getconf >/dev/null 2>&1; then
        getconf _NPROCESSORS_ONLN
        return
    fi
    echo 1
}

for arg in "$@"; do
    case "$arg" in
        release|--release) PROFILE="release" ;;
        lite|--lite) IS_LITE=1 ;;
        gpu|--gpu) IS_GPU=1 ;;
    esac
done

if [ "$PROFILE" = "release" ]; then
    CARGO_FLAGS="--release"
    TARGET_DIR="release"
else
    TARGET_DIR="debug"
fi

CPU_COUNT="$(detect_cpu_count)"
DEFAULT_BUILD_JOBS=$(( CPU_COUNT > 2 ? CPU_COUNT - 2 : 1 ))
BUILD_JOBS="${BUILD_JOBS:-${DEFAULT_BUILD_JOBS}}"
if ! [[ "${BUILD_JOBS}" =~ ^[0-9]+$ ]] || [ "${BUILD_JOBS}" -lt 1 ]; then
    echo "Error: BUILD_JOBS must be a positive integer, got '${BUILD_JOBS}'." >&2
    exit 1
fi
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-${BUILD_JOBS}}"

if [ $IS_LITE -eq 1 ]; then
    echo "--- LITE build enabled (rayon/regex disabled) ---"
    CARGO_FLAGS="$CARGO_FLAGS --no-default-features --features lite"
elif [ $IS_GPU -eq 1 ]; then
    echo "--- GPU build enabled ---"
    CARGO_FLAGS="$CARGO_FLAGS --features gpu"
else
    echo "--- Default build enabled (includes rayon/regex) ---"
fi

CRATE_DIR="../crate"
INCLUDE_DIR="../include"
OUT_DIR="../../../target/ocx"
TYPELIB_OUT="${OUT_DIR}/VolvoxGrid.tlb"
TYPELIB_CONTRACT_SRC="../src/VolvoxGrid_contract.tlb"
# Resolve cargo target directory for finding the static lib (respects .cargo/config.toml target-dir)
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$(cargo metadata --format-version 1 --no-deps --manifest-path "$CRATE_DIR/Cargo.toml" 2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['target_directory'])" 2>/dev/null || echo "../../../target")}"
mkdir -p "$OUT_DIR"

echo "=== Installing VolvoxGrid type library ==="
if [ ! -f "$TYPELIB_CONTRACT_SRC" ]; then
    echo "ERROR: missing checked-in typelib contract: $TYPELIB_CONTRACT_SRC" >&2
    exit 1
fi
install -m 0644 "$TYPELIB_CONTRACT_SRC" "$TYPELIB_OUT"

echo "=== Building VolvoxGrid.ocx ($PROFILE) ==="
echo "Using BUILD_JOBS=${BUILD_JOBS} (cpu=${CPU_COUNT}, cargo=${CARGO_BUILD_JOBS})"

# ── x86 (32-bit) ──────────────────────────────────────────────
build_arch() {
    local ARCH="$1"        # i686 or x86_64
    local TRIPLE="${ARCH}-pc-windows-gnu"
    local CC="${ARCH}-w64-mingw32-gcc"
    local STRIP="${ARCH}-w64-mingw32-strip"
    local STATIC_LIB="${CARGO_TARGET_DIR}/${TRIPLE}/${TARGET_DIR}/libvolvoxgrid_activex.a"

    echo ""
    echo "── ${ARCH} ──"

    # 1) Build Rust staticlib
    echo "  Cargo build (${TRIPLE})..."
    cd "$CRATE_DIR"
    cargo build -j "${CARGO_BUILD_JOBS}" --target "$TRIPLE" $CARGO_FLAGS
    cd - > /dev/null

    if [ ! -f "$STATIC_LIB" ]; then
        echo "Error: Static lib not found: $STATIC_LIB"
        exit 1
    fi

    # 2) Compile C sources
    echo "  Compile C sources..."
    local CFLAGS="-O2 -Wall -I${INCLUDE_DIR}"
    local -a PIDS=()
    $CC $CFLAGS -c dllexports.c -o "${OUT_DIR}/dllexports_${ARCH}.o" &
    PIDS+=($!)
    $CC $CFLAGS -c volvoxgrid_ocx.c -o "${OUT_DIR}/volvoxgrid_ocx_${ARCH}.o" &
    PIDS+=($!)
    $CC $CFLAGS -c compat_shims.c -o "${OUT_DIR}/compat_shims_${ARCH}.o" &
    PIDS+=($!)
    $CC $CFLAGS -c xp_compat.c -o "${OUT_DIR}/xp_compat_${ARCH}.o" &
    PIDS+=($!)
    for pid in "${PIDS[@]}"; do
        wait "$pid"
    done

    # 3) Link into OCX (DLL)
    #    xp_compat.o MUST come before $STATIC_LIB so its symbols override
    #    the Rust archive's DLL import stubs (bcryptprimitives, synch APIs)
    #    and the MinGW import libs (KERNEL32 Vista+ functions).
    echo "  Link VolvoxGrid_${ARCH}.ocx..."
    $CC -shared -o "${OUT_DIR}/VolvoxGrid_${ARCH}.ocx" \
        "${OUT_DIR}/dllexports_${ARCH}.o" \
        "${OUT_DIR}/volvoxgrid_ocx_${ARCH}.o" \
        "${OUT_DIR}/compat_shims_${ARCH}.o" \
        "${OUT_DIR}/xp_compat_${ARCH}.o" \
        "$STATIC_LIB" \
        VolvoxGrid.def \
        -lole32 -loleaut32 -luuid -lcomdlg32 -lurlmon -lgdiplus -ladvapi32 -lws2_32 -luserenv -lbcrypt \
        -lgdi32 -lntdll \
        -static-libgcc \
        -Wl,--enable-stdcall-fixup,--allow-multiple-definition

    if [ "$PROFILE" = "release" ]; then
        $STRIP "${OUT_DIR}/VolvoxGrid_${ARCH}.ocx"
    fi

    local SIZE=$(stat -c%s "${OUT_DIR}/VolvoxGrid_${ARCH}.ocx" 2>/dev/null || stat -f%z "${OUT_DIR}/VolvoxGrid_${ARCH}.ocx")
    echo "  Done: ${OUT_DIR}/VolvoxGrid_${ARCH}.ocx ($(($SIZE / 1024)) KB)"

    # 4) Build test program
    echo "  Build grid_capture_test_${ARCH}.exe..."
    $CC $CFLAGS -o "${OUT_DIR}/grid_capture_test_${ARCH}.exe" \
        grid_capture_test.c \
        -lole32 -loleaut32 -luuid -lgdi32 \
        -static-libgcc
    echo "  Done: ${OUT_DIR}/grid_capture_test_${ARCH}.exe"

    # 5) Build comparison test
    echo "  Build grid_compare_test_${ARCH}.exe..."
    $CC $CFLAGS -o "${OUT_DIR}/grid_compare_test_${ARCH}.exe" \
        grid_compare_test.c \
        -lole32 -loleaut32 -luuid -lgdi32 \
        -static-libgcc
    echo "  Done: ${OUT_DIR}/grid_compare_test_${ARCH}.exe"

    echo "  Build gdi_measure_text_${ARCH}.exe..."
    $CC $CFLAGS -o "${OUT_DIR}/gdi_measure_text_${ARCH}.exe" \
        gdi_measure_text.c \
        -lgdi32 \
        -static-libgcc
    echo "  Done: ${OUT_DIR}/gdi_measure_text_${ARCH}.exe"

    echo "  Build volvoxgrid_demo_host_${ARCH}.exe..."
    $CC $CFLAGS -o "${OUT_DIR}/volvoxgrid_demo_host_${ARCH}.exe" \
        activex_demo_host.c \
        -lole32 -loleaut32 -luuid -lgdi32 -limm32 \
        -mwindows -static-libgcc
    echo "  Done: ${OUT_DIR}/volvoxgrid_demo_host_${ARCH}.exe"

}

# Build both architectures (skip if toolchain not available)
if command -v i686-w64-mingw32-gcc >/dev/null 2>&1; then
    build_arch i686
else
    echo "Skipping i686: i686-w64-mingw32-gcc not found"
fi

if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    build_arch x86_64
else
    echo "Skipping x86_64: x86_64-w64-mingw32-gcc not found"
fi

echo ""
echo "=== Build complete ==="
ls -la "$OUT_DIR"/*.ocx 2>/dev/null || echo "No OCX files built (missing cross-compilers)."
