#!/usr/bin/env bash
set -euo pipefail

# Desktop JAR packaging script — runs inside Docker (Dockerfile.desktop).
#
# Cross-compiles the Rust volvoxgrid native library for linux-x86_64, linux-x86,
# linux-aarch64, linux-armv7, windows-x86_64, macos-x86_64, macos-aarch64,
# then packages a fat JAR
# with classes from volvoxgrid-java-common + embedded native/ libraries.
#
# Usage (inside Docker): VERSION=0.8.9 /opt/volvoxgrid/build_desktop_jar.sh
# Optional: LIBRARY_BUILD_MODE=lite (default: full)

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
VERSION="${VERSION:-0.8.9}"
SYNURANG_VERSION="${SYNURANG_VERSION:-0.5.4}"
GROUP_ID="${GROUP_ID:-io.github.ivere27}"
ARTIFACT_ID="${ARTIFACT_ID:-volvoxgrid-desktop}"
LIBRARY_BUILD_MODE="${LIBRARY_BUILD_MODE:-full}"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/maven}"
BUILD_OCX="${BUILD_OCX:-1}"
OCX_DIST_DIR="${OCX_DIST_DIR:-${REPO_ROOT}/dist/desktop/ocx}"
BUILD_DOTNET="${BUILD_DOTNET:-0}"
DOTNET_DIST_DIR="${DOTNET_DIST_DIR:-${REPO_ROOT}/dist/dotnet}"
BUILD_DEBUG_SYMBOLS="${BUILD_DEBUG_SYMBOLS:-1}"
DEBUG_SYMBOLS_DIR="${DEBUG_SYMBOLS_DIR:-${REPO_ROOT}/dist/symbols}"

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

CPU_COUNT="$(detect_cpu_count)"
DEFAULT_BUILD_JOBS=$(( CPU_COUNT > 2 ? CPU_COUNT - 2 : 1 ))
BUILD_JOBS="${BUILD_JOBS:-${DEFAULT_BUILD_JOBS}}"
if ! [[ "${BUILD_JOBS}" =~ ^[0-9]+$ ]] || [[ "${BUILD_JOBS}" -lt 1 ]]; then
  echo "Error: BUILD_JOBS must be a positive integer, got '${BUILD_JOBS}'." >&2
  exit 1
fi
export BUILD_JOBS
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-${BUILD_JOBS}}"
GRADLE_MAX_WORKERS="${GRADLE_MAX_WORKERS:-${BUILD_JOBS}}"
case "${LIBRARY_BUILD_MODE}" in
  full)
    LIBRARY_FEATURE_ARGS=(--features gpu)
    POM_DESCRIPTION="VolvoxGrid pixel-rendering grid engine for desktop (Linux, macOS, Windows)"
    ;;
  lite)
    LIBRARY_FEATURE_ARGS=(--no-default-features --features demo)
    POM_DESCRIPTION="VolvoxGrid lite pixel-rendering grid engine for desktop (Linux, macOS, Windows)"
    ;;
  *)
    echo "Error: LIBRARY_BUILD_MODE must be 'full' or 'lite', got '${LIBRARY_BUILD_MODE}'." >&2
    exit 1
    ;;
esac
echo "Using BUILD_JOBS=${BUILD_JOBS} (cpu=${CPU_COUNT}, cargo=${CARGO_BUILD_JOBS}, gradle=${GRADLE_MAX_WORKERS}, mode=${LIBRARY_BUILD_MODE}, debug_symbols=${BUILD_DEBUG_SYMBOLS})"

# Metadata consumed by engine/build.rs for embedding into binaries.
export VOLVOXGRID_VERSION="${VOLVOXGRID_VERSION:-${VERSION}}"
export VOLVOXGRID_GIT_COMMIT="${VOLVOXGRID_GIT_COMMIT:-${GIT_COMMIT}}"
export VOLVOXGRID_BUILD_DATE="${VOLVOXGRID_BUILD_DATE:-${BUILD_DATE}}"

WORK_DIR="$(mktemp -d /tmp/volvoxgrid-desktop-XXXXXX)"
NATIVES_DIR="${WORK_DIR}/natives"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

should_build_dotnet() {
  case "${BUILD_DOTNET}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
  esac
  return 1
}

should_build_debug_symbols() {
  case "${BUILD_DEBUG_SYMBOLS}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
  esac
  return 1
}

strip_macos_dylib() {
  bash "${REPO_ROOT}/scripts/strip_macos_dylibs.sh" "$1"
}

SYMBOLS_STAGE_ROOT="${WORK_DIR}/debug-symbols/${ARTIFACT_ID}-${VERSION}-debug-symbols"
CARGO_RELEASE_ARGS=(-j "${CARGO_BUILD_JOBS}" --release)
if should_build_debug_symbols; then
  CARGO_RELEASE_ARGS+=(--config 'profile.release.debug="line-tables-only"')
  CARGO_RELEASE_ARGS+=(--config 'profile.release.strip="none"')
fi

process_native_library() {
  local platform="$1"
  local library="$2"

  if should_build_debug_symbols; then
    bash "${REPO_ROOT}/scripts/split_native_debug_symbols.sh" \
      "${platform}" \
      "${library}" \
      "${SYMBOLS_STAGE_ROOT}/native/${platform}"
  elif [[ "${platform}" == macos-* ]]; then
    strip_macos_dylib "${library}"
  fi
}

collect_dotnet_symbols() {
  local label="$1"
  shift

  if ! should_build_debug_symbols; then
    return 0
  fi

  local out_dir="${SYMBOLS_STAGE_ROOT}/dotnet/${label}"
  local dir
  local pdb
  for dir in "$@"; do
    [[ -d "${dir}" ]] || continue
    for pdb in "${dir}"/*.pdb; do
      [[ -f "${pdb}" ]] || continue
      mkdir -p "${out_dir}"
      cp -f "${pdb}" "${out_dir}/"
    done
  done
}

finalize_debug_symbols() {
  if ! should_build_debug_symbols; then
    return 0
  fi

  local symbols_parent="${WORK_DIR}/debug-symbols"
  if [[ ! -d "${symbols_parent}" ]] || ! find "${symbols_parent}" -mindepth 2 -print -quit | grep -q .; then
    echo "No debug symbols captured."
    return 0
  fi

  mkdir -p "${DEBUG_SYMBOLS_DIR}"

  local root
  for root in "${symbols_parent}"/*-debug-symbols; do
    [[ -d "${root}" ]] || continue
    if ! find "${root}" -mindepth 1 -print -quit | grep -q .; then
      continue
    fi

    local base
    local artifact_id
    local zip_path
    base="$(basename "${root}")"
    artifact_id="${base%-${VERSION}-debug-symbols}"

    mkdir -p "${root}/META-INF/volvoxgrid"
    cat > "${root}/META-INF/volvoxgrid/build-info.properties" <<META
volvoxgrid.version=${VERSION}
volvoxgrid.artifact_id=${artifact_id}
volvoxgrid.git_commit=${GIT_COMMIT}
volvoxgrid.build_date=${BUILD_DATE}
META

    zip_path="$(cd "${DEBUG_SYMBOLS_DIR}" && pwd)/${base}.zip"
    rm -f "${zip_path}"
    (cd "${symbols_parent}" && zip -qr "${zip_path}" "${base}")
    echo "Built debug symbols: ${zip_path}"
  done
}

LIBRARY_CRATE="${REPO_ROOT}/runtime"
if [[ ! -f "${LIBRARY_CRATE}/Cargo.toml" ]]; then
  echo "Error: native library crate not found at ${LIBRARY_CRATE}" >&2
  exit 1
fi

VSFLEXGRID_MINGW_DIR="${REPO_ROOT}/adapters/vsflexgrid/mingw"

# ── Configure Cargo cross-linkers via env (no repo file mutation) ───────────
export CARGO_TARGET_I686_UNKNOWN_LINUX_GNU_LINKER="i686-linux-gnu-gcc"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="aarch64-linux-gnu-gcc"
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER="arm-linux-gnueabihf-gcc"
export CARGO_TARGET_I686_PC_WINDOWS_GNU_LINKER="i686-w64-mingw32-gcc"
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER="x86_64-w64-mingw32-gcc"
export CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER="/opt/volvoxgrid/zig-cc-x86_64-macos.sh"
export CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER="/opt/volvoxgrid/zig-cc-aarch64-macos.sh"

# ── Cross-compile Rust library for each platform ────────────────────────────

# linux-x86_64 (native)
echo "Building library: linux-x86_64..."
(cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target x86_64-unknown-linux-gnu "${LIBRARY_FEATURE_ARGS[@]}")
mkdir -p "${NATIVES_DIR}/linux-x86_64"
cp "${CARGO_TARGET_DIR}/x86_64-unknown-linux-gnu/release/libvolvoxgrid.so" "${NATIVES_DIR}/linux-x86_64/"
process_native_library "linux-x86_64" "${NATIVES_DIR}/linux-x86_64/libvolvoxgrid.so"

# linux-x86 (cross-compile)
if command -v i686-linux-gnu-gcc >/dev/null 2>&1; then
  echo "Building library: linux-x86..."
  (cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target i686-unknown-linux-gnu "${LIBRARY_FEATURE_ARGS[@]}")
  mkdir -p "${NATIVES_DIR}/linux-x86"
  cp "${CARGO_TARGET_DIR}/i686-unknown-linux-gnu/release/libvolvoxgrid.so" "${NATIVES_DIR}/linux-x86/"
  process_native_library "linux-x86" "${NATIVES_DIR}/linux-x86/libvolvoxgrid.so"
else
  echo "SKIP: linux-x86 (i686-linux-gnu-gcc not found)"
fi

# linux-aarch64 (cross-compile)
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  echo "Building library: linux-aarch64..."
  (cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target aarch64-unknown-linux-gnu "${LIBRARY_FEATURE_ARGS[@]}")
  mkdir -p "${NATIVES_DIR}/linux-aarch64"
  cp "${CARGO_TARGET_DIR}/aarch64-unknown-linux-gnu/release/libvolvoxgrid.so" "${NATIVES_DIR}/linux-aarch64/"
  process_native_library "linux-aarch64" "${NATIVES_DIR}/linux-aarch64/libvolvoxgrid.so"
else
  echo "SKIP: linux-aarch64 (aarch64-linux-gnu-gcc not found)"
fi

# linux-armv7 (cross-compile)
if command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
  echo "Building library: linux-armv7..."
  (cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target armv7-unknown-linux-gnueabihf "${LIBRARY_FEATURE_ARGS[@]}")
  mkdir -p "${NATIVES_DIR}/linux-armv7"
  cp "${CARGO_TARGET_DIR}/armv7-unknown-linux-gnueabihf/release/libvolvoxgrid.so" "${NATIVES_DIR}/linux-armv7/"
  process_native_library "linux-armv7" "${NATIVES_DIR}/linux-armv7/libvolvoxgrid.so"
else
  echo "SKIP: linux-armv7 (arm-linux-gnueabihf-gcc not found)"
fi

# windows-x86 (MinGW cross-compile)
if command -v i686-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "Building library: windows-x86..."
  (cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target i686-pc-windows-gnu "${LIBRARY_FEATURE_ARGS[@]}")
  mkdir -p "${NATIVES_DIR}/windows-x86"
  cp "${CARGO_TARGET_DIR}/i686-pc-windows-gnu/release/volvoxgrid.dll" "${NATIVES_DIR}/windows-x86/"
  process_native_library "windows-x86" "${NATIVES_DIR}/windows-x86/volvoxgrid.dll"
else
  echo "SKIP: windows-x86 (i686-w64-mingw32-gcc not found)"
fi

# windows-x86_64 (MinGW cross-compile)
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "Building library: windows-x86_64..."
  (cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target x86_64-pc-windows-gnu "${LIBRARY_FEATURE_ARGS[@]}")
  mkdir -p "${NATIVES_DIR}/windows-x86_64"
  cp "${CARGO_TARGET_DIR}/x86_64-pc-windows-gnu/release/volvoxgrid.dll" "${NATIVES_DIR}/windows-x86_64/"
  process_native_library "windows-x86_64" "${NATIVES_DIR}/windows-x86_64/volvoxgrid.dll"
else
  echo "SKIP: windows-x86_64 (x86_64-w64-mingw32-gcc not found)"
fi

# ActiveX OCX artifacts (release + release lite)
if [[ "${BUILD_OCX}" == "0" ]]; then
  echo "SKIP: ActiveX OCX build (BUILD_OCX=0)"
elif [[ ! -d "${VSFLEXGRID_MINGW_DIR}" ]]; then
  echo "SKIP: ActiveX OCX build (missing ${VSFLEXGRID_MINGW_DIR})"
elif ! command -v i686-w64-mingw32-gcc >/dev/null 2>&1 || ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "SKIP: ActiveX OCX build (MinGW cross-compilers not found)"
else
  build_ocx_variant() {
    local flavor="$1"      # release or release-lite
    local output_suffix="$2" # "" or "lite"
    shift 2
    local -a extra_args=("$@")

    echo "Building ActiveX OCX: ${flavor}..."
    (
      cd "${VSFLEXGRID_MINGW_DIR}"
      BUILD_DEBUG_SYMBOLS="${BUILD_DEBUG_SYMBOLS}" \
      DEBUG_SYMBOLS_DIR="${WORK_DIR}/debug-symbols/volvoxgrid-activex-${VERSION}-debug-symbols/ocx/${flavor}" \
        ./build_ocx.sh release "${extra_args[@]}"
    )

    mkdir -p "${OCX_DIST_DIR}"
    for arch in i686 x86_64; do
      local src="${REPO_ROOT}/target/ocx/VolvoxGrid_${arch}.ocx"
      local dst="${OCX_DIST_DIR}/VolvoxGrid_${arch}.ocx"
      if [[ -n "${output_suffix}" ]]; then
        dst="${OCX_DIST_DIR}/VolvoxGrid_${arch}.${output_suffix}.ocx"
      fi
      if [[ ! -f "${src}" ]]; then
        echo "Error: expected OCX not found at ${src}" >&2
        exit 1
      fi
      cp -f "${src}" "${dst}"
    done
  }

  build_ocx_variant "release" ""
  build_ocx_variant "release-lite" "lite" lite
  echo "Built ActiveX OCX artifacts: ${OCX_DIST_DIR}"
fi

# macos-x86_64 (zig cross-compile)
if command -v zig >/dev/null 2>&1; then
  echo "Building library: macos-x86_64..."
  (cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target x86_64-apple-darwin "${LIBRARY_FEATURE_ARGS[@]}")
  mkdir -p "${NATIVES_DIR}/macos-x86_64"
  cp "${CARGO_TARGET_DIR}/x86_64-apple-darwin/release/libvolvoxgrid.dylib" "${NATIVES_DIR}/macos-x86_64/"
  process_native_library "macos-x86_64" "${NATIVES_DIR}/macos-x86_64/libvolvoxgrid.dylib"

  echo "Building library: macos-aarch64..."
  (cd "${LIBRARY_CRATE}" && cargo build "${CARGO_RELEASE_ARGS[@]}" --target aarch64-apple-darwin "${LIBRARY_FEATURE_ARGS[@]}")
  mkdir -p "${NATIVES_DIR}/macos-aarch64"
  cp "${CARGO_TARGET_DIR}/aarch64-apple-darwin/release/libvolvoxgrid.dylib" "${NATIVES_DIR}/macos-aarch64/"
  process_native_library "macos-aarch64" "${NATIVES_DIR}/macos-aarch64/libvolvoxgrid.dylib"
else
  echo "SKIP: macos-x86_64, macos-aarch64 (zig not found)"
fi

# ── Build Java classes via Gradle ───────────────────────────────────────────
GRADLE_REPO_INIT="${WORK_DIR}/gradle-repositories.init.gradle"
cat > "${GRADLE_REPO_INIT}" <<'GRADLE'
allprojects {
  repositories {
    mavenCentral()
    google()
  }
}
GRADLE

JAVA_COMMON_DIR="${REPO_ROOT}/java/common"
if [[ ! -d "${JAVA_COMMON_DIR}" ]]; then
  echo "Error: java/common not found at ${JAVA_COMMON_DIR}" >&2
  exit 1
fi

echo "Building volvoxgrid-java-common JAR..."
gradle -p "${JAVA_COMMON_DIR}" --no-daemon --max-workers="${GRADLE_MAX_WORKERS}" -I "${GRADLE_REPO_INIT}" clean jar

COMMON_JAR="$(find "${JAVA_COMMON_DIR}/build/libs" -maxdepth 1 -type f -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | head -n 1)"
if [[ -z "${COMMON_JAR}" || ! -f "${COMMON_JAR}" ]]; then
  echo "Error: volvoxgrid-java-common jar build failed." >&2
  exit 1
fi

# ── Package fat JAR (classes + native/) ─────────────────────────────────────
JAR_DIR="${WORK_DIR}/desktop-jar"
mkdir -p "${JAR_DIR}"

# Extract common classes
(cd "${JAR_DIR}" && jar xf "${COMMON_JAR}")

# Embed native libraries
NATIVE_COUNT=0
for PLATFORM_DIR in "${NATIVES_DIR}"/*/; do
  [[ -d "${PLATFORM_DIR}" ]] || continue
  PLATFORM="$(basename "${PLATFORM_DIR}")"
  mkdir -p "${JAR_DIR}/native/${PLATFORM}"
  for LIB in "${PLATFORM_DIR}"/*; do
    [[ -f "${LIB}" ]] || continue
    cp "${LIB}" "${JAR_DIR}/native/${PLATFORM}/"
    NATIVE_COUNT=$((NATIVE_COUNT + 1))
  done
done

if [[ "${NATIVE_COUNT}" -eq 0 ]]; then
  echo "Error: no native libraries were built." >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
JAR_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}.jar"
mkdir -p "${JAR_DIR}/META-INF/volvoxgrid"
cat > "${JAR_DIR}/META-INF/volvoxgrid/build-info.properties" <<META
volvoxgrid.version=${VERSION}
volvoxgrid.git_commit=${GIT_COMMIT}
volvoxgrid.build_date=${BUILD_DATE}
META
MANIFEST_FILE="${WORK_DIR}/MANIFEST.MF"
cat > "${MANIFEST_FILE}" <<MANIFEST
Manifest-Version: 1.0
Implementation-Title: ${ARTIFACT_ID}
Implementation-Version: ${VERSION}
VolvoxGrid-Git-Commit: ${GIT_COMMIT}
VolvoxGrid-Build-Date: ${BUILD_DATE}

MANIFEST
(cd "${JAR_DIR}" && jar cfm "${JAR_OUT}" "${MANIFEST_FILE}" .)
echo "Built: ${JAR_OUT} (${NATIVE_COUNT} native libs embedded)"

# ── Generate POM ────────────────────────────────────────────────────────────
POM_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}.pom"
cat > "${POM_OUT}" <<POM
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>${GROUP_ID}</groupId>
  <artifactId>${ARTIFACT_ID}</artifactId>
  <version>${VERSION}</version>
  <packaging>jar</packaging>
  <name>${ARTIFACT_ID}</name>
  <description>${POM_DESCRIPTION}</description>
  <url>https://github.com/ivere27/volvoxgrid</url>
  <licenses>
    <license>
      <name>Apache License, Version 2.0</name>
      <url>https://www.apache.org/licenses/LICENSE-2.0</url>
    </license>
  </licenses>
  <developers>
    <developer>
      <id>ivere27</id>
      <name>ivere27</name>
      <url>https://github.com/ivere27</url>
    </developer>
  </developers>
  <scm>
    <connection>scm:git:git://github.com/ivere27/volvoxgrid.git</connection>
    <developerConnection>scm:git:ssh://github.com:ivere27/volvoxgrid.git</developerConnection>
    <url>https://github.com/ivere27/volvoxgrid</url>
  </scm>
  <dependencies>
    <dependency>
      <groupId>io.github.ivere27</groupId>
      <artifactId>synurang-desktop</artifactId>
      <version>${SYNURANG_VERSION}</version>
    </dependency>
  </dependencies>
</project>
POM

# ── Generate sources.jar and javadoc.jar ────────────────────────────────────
SOURCES_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}-sources.jar"
JAVADOC_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}-javadoc.jar"

SOURCES_DIR="${WORK_DIR}/sources"
mkdir -p "${SOURCES_DIR}"
JAVA_SRC="${JAVA_COMMON_DIR}/src/main/java"
if [[ -d "${JAVA_SRC}" ]]; then
  cp -r "${JAVA_SRC}/." "${SOURCES_DIR}/"
fi
(cd "${SOURCES_DIR}" && jar cf "${SOURCES_OUT}" .)

JAVADOC_DIR="${WORK_DIR}/javadoc"
mkdir -p "${JAVADOC_DIR}"
(cd "${JAVADOC_DIR}" && jar cf "${JAVADOC_OUT}" .)

DOTNET_STAGE_OUT_X64=""
DOTNET_STAGE_OUT_X86=""
DOTNET_LITE_STAGE_OUT_X64=""
DOTNET_LITE_STAGE_OUT_X86=""
if should_build_dotnet; then
  echo ""
  echo "Building .NET WinForms artifacts (release, net40, x64+x86, full+lite)..."
  if ! command -v dotnet >/dev/null 2>&1; then
    echo "Error: dotnet CLI not found in Docker image." >&2
    exit 1
  fi

  if [[ ! -f "${REPO_ROOT}/dotnet/build_dotnet.sh" ]]; then
    echo "Error: dotnet/build_dotnet.sh not found in repository." >&2
    exit 1
  fi

  (
    cd "${REPO_ROOT}"
    DOTNET_TFM=net40 DOTNET_ARCH=x64 bash "${REPO_ROOT}/dotnet/build_dotnet.sh" release
    DOTNET_TFM=net40 DOTNET_ARCH=x86 bash "${REPO_ROOT}/dotnet/build_dotnet.sh" release
  )

  DOTNET_STAGE_DIR_X64="${REPO_ROOT}/target/dotnet/winforms_release"
  DOTNET_STAGE_DIR_X86="${REPO_ROOT}/target/dotnet/winforms_release_x86"
  if [[ ! -d "${DOTNET_STAGE_DIR_X64}" ]]; then
    echo "Error: expected .NET stage directory not found: ${DOTNET_STAGE_DIR_X64}" >&2
    exit 1
  fi
  if [[ ! -d "${DOTNET_STAGE_DIR_X86}" ]]; then
    echo "Error: expected .NET stage directory not found: ${DOTNET_STAGE_DIR_X86}" >&2
    exit 1
  fi

  DOTNET_STAGE_OUT_X64="${DOTNET_DIST_DIR}/winforms_release"
  DOTNET_STAGE_OUT_X86="${DOTNET_DIST_DIR}/winforms_release_x86"
  DOTNET_MSBUILD_ROOT="${REPO_ROOT}/target/dotnet/msbuild"
  mkdir -p "${DOTNET_STAGE_OUT_X64}" "${DOTNET_STAGE_OUT_X86}"
  cp -a "${DOTNET_STAGE_DIR_X64}/." "${DOTNET_STAGE_OUT_X64}/"
  cp -a "${DOTNET_STAGE_DIR_X86}/." "${DOTNET_STAGE_OUT_X86}/"
  collect_dotnet_symbols "winforms_release_x64" \
    "${DOTNET_STAGE_OUT_X64}" \
    "${DOTNET_MSBUILD_ROOT}/bin/x64/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/bin/x64/VolvoxGrid.WinFormsSample/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x64/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x64/VolvoxGrid.WinFormsSample/Release/net40"
  collect_dotnet_symbols "winforms_release_x86" \
    "${DOTNET_STAGE_OUT_X86}" \
    "${DOTNET_MSBUILD_ROOT}/bin/x86/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/bin/x86/VolvoxGrid.WinFormsSample/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x86/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x86/VolvoxGrid.WinFormsSample/Release/net40"

  echo ""
  echo "Building .NET WinForms lite artifacts (release, net40, x64+x86)..."
  (
    cd "${REPO_ROOT}"
    CARGO_TARGET_DIR="${REPO_ROOT}/target/dotnet/lite-cargo" VOLVOXGRID_VARIANT=lite DOTNET_TFM=net40 DOTNET_ARCH=x64 bash "${REPO_ROOT}/dotnet/build_dotnet.sh" release
    CARGO_TARGET_DIR="${REPO_ROOT}/target/dotnet/lite-cargo" VOLVOXGRID_VARIANT=lite DOTNET_TFM=net40 DOTNET_ARCH=x86 bash "${REPO_ROOT}/dotnet/build_dotnet.sh" release
  )

  DOTNET_LITE_STAGE_OUT_X64="${DOTNET_DIST_DIR}/winforms_release_lite"
  DOTNET_LITE_STAGE_OUT_X86="${DOTNET_DIST_DIR}/winforms_release_lite_x86"
  mkdir -p "${DOTNET_LITE_STAGE_OUT_X64}" "${DOTNET_LITE_STAGE_OUT_X86}"
  cp -a "${DOTNET_STAGE_DIR_X64}/." "${DOTNET_LITE_STAGE_OUT_X64}/"
  cp -a "${DOTNET_STAGE_DIR_X86}/." "${DOTNET_LITE_STAGE_OUT_X86}/"
  collect_dotnet_symbols "winforms_release_lite_x64" \
    "${DOTNET_LITE_STAGE_OUT_X64}" \
    "${DOTNET_MSBUILD_ROOT}/bin/x64/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/bin/x64/VolvoxGrid.WinFormsSample/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x64/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x64/VolvoxGrid.WinFormsSample/Release/net40"
  collect_dotnet_symbols "winforms_release_lite_x86" \
    "${DOTNET_LITE_STAGE_OUT_X86}" \
    "${DOTNET_MSBUILD_ROOT}/bin/x86/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/bin/x86/VolvoxGrid.WinFormsSample/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x86/VolvoxGrid.DotNet/Release/net40" \
    "${DOTNET_MSBUILD_ROOT}/obj/x86/VolvoxGrid.WinFormsSample/Release/net40"

  rm -rf "${DOTNET_STAGE_DIR_X64}" "${DOTNET_STAGE_DIR_X86}"
  mkdir -p "${DOTNET_STAGE_DIR_X64}" "${DOTNET_STAGE_DIR_X86}"
  cp -a "${DOTNET_STAGE_OUT_X64}/." "${DOTNET_STAGE_DIR_X64}/"
  cp -a "${DOTNET_STAGE_OUT_X86}/." "${DOTNET_STAGE_DIR_X86}/"
fi

finalize_debug_symbols

echo ""
echo "Built desktop JAR artifacts:"
echo "  ${JAR_OUT}"
echo "  ${POM_OUT}"
echo "  ${SOURCES_OUT}"
echo "  ${JAVADOC_OUT}"
if [[ -n "${DOTNET_STAGE_OUT_X64}" || -n "${DOTNET_STAGE_OUT_X86}" ]]; then
  echo "Built .NET artifacts:"
  if [[ -n "${DOTNET_STAGE_OUT_X64}" ]]; then
    echo "  ${DOTNET_STAGE_OUT_X64}"
  fi
  if [[ -n "${DOTNET_STAGE_OUT_X86}" ]]; then
    echo "  ${DOTNET_STAGE_OUT_X86}"
  fi
  if [[ -n "${DOTNET_LITE_STAGE_OUT_X64}" ]]; then
    echo "  ${DOTNET_LITE_STAGE_OUT_X64}"
  fi
  if [[ -n "${DOTNET_LITE_STAGE_OUT_X86}" ]]; then
    echo "  ${DOTNET_LITE_STAGE_OUT_X86}"
  fi
fi
if should_build_debug_symbols && [[ -f "${DEBUG_SYMBOLS_DIR}/${ARTIFACT_ID}-${VERSION}-debug-symbols.zip" ]]; then
  echo "Built debug symbols:"
  echo "  ${DEBUG_SYMBOLS_DIR}/${ARTIFACT_ID}-${VERSION}-debug-symbols.zip"
fi
