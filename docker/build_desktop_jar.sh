#!/usr/bin/env bash
set -euo pipefail

# Desktop JAR packaging script — runs inside Docker (Dockerfile.desktop).
#
# Cross-compiles the Rust volvoxgrid plugin for linux-x86_64, linux-x86,
# linux-aarch64, linux-armv7, windows-x86_64, macos-x86_64, macos-aarch64,
# then packages a fat JAR
# with classes from volvoxgrid-java-common + embedded native/ libraries.
#
# Usage (inside Docker): VERSION=0.8.2 /opt/volvoxgrid/build_desktop_jar.sh

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
VERSION="${VERSION:-0.8.2}"
SYNURANG_VERSION="${SYNURANG_VERSION:-0.5.4}"
GROUP_ID="${GROUP_ID:-io.github.ivere27}"
ARTIFACT_ID="${ARTIFACT_ID:-volvoxgrid-desktop}"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/maven}"
BUILD_OCX="${BUILD_OCX:-1}"
OCX_DIST_DIR="${OCX_DIST_DIR:-${REPO_ROOT}/dist/desktop/ocx}"
BUILD_DOTNET="${BUILD_DOTNET:-0}"
DOTNET_DIST_DIR="${DOTNET_DIST_DIR:-${REPO_ROOT}/dist/dotnet}"

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
echo "Using BUILD_JOBS=${BUILD_JOBS} (cpu=${CPU_COUNT}, cargo=${CARGO_BUILD_JOBS}, gradle=${GRADLE_MAX_WORKERS})"

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

PLUGIN_CRATE="${REPO_ROOT}/plugin"
if [[ ! -f "${PLUGIN_CRATE}/Cargo.toml" ]]; then
  echo "Error: plugin crate not found at ${PLUGIN_CRATE}" >&2
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

# ── Cross-compile Rust plugin for each platform ────────────────────────────

# linux-x86_64 (native)
echo "Building plugin: linux-x86_64..."
(cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target x86_64-unknown-linux-gnu)
mkdir -p "${NATIVES_DIR}/linux-x86_64"
cp "${CARGO_TARGET_DIR}/x86_64-unknown-linux-gnu/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-x86_64/"

# linux-x86 (cross-compile)
if command -v i686-linux-gnu-gcc >/dev/null 2>&1; then
  echo "Building plugin: linux-x86..."
  (cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target i686-unknown-linux-gnu)
  mkdir -p "${NATIVES_DIR}/linux-x86"
  cp "${CARGO_TARGET_DIR}/i686-unknown-linux-gnu/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-x86/"
else
  echo "SKIP: linux-x86 (i686-linux-gnu-gcc not found)"
fi

# linux-aarch64 (cross-compile)
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  echo "Building plugin: linux-aarch64..."
  (cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target aarch64-unknown-linux-gnu)
  mkdir -p "${NATIVES_DIR}/linux-aarch64"
  cp "${CARGO_TARGET_DIR}/aarch64-unknown-linux-gnu/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-aarch64/"
else
  echo "SKIP: linux-aarch64 (aarch64-linux-gnu-gcc not found)"
fi

# linux-armv7 (cross-compile)
if command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
  echo "Building plugin: linux-armv7..."
  (cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target armv7-unknown-linux-gnueabihf)
  mkdir -p "${NATIVES_DIR}/linux-armv7"
  cp "${CARGO_TARGET_DIR}/armv7-unknown-linux-gnueabihf/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-armv7/"
else
  echo "SKIP: linux-armv7 (arm-linux-gnueabihf-gcc not found)"
fi

# windows-x86 (MinGW cross-compile)
if command -v i686-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "Building plugin: windows-x86..."
  (cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target i686-pc-windows-gnu)
  mkdir -p "${NATIVES_DIR}/windows-x86"
  cp "${CARGO_TARGET_DIR}/i686-pc-windows-gnu/release/volvoxgrid_plugin.dll" "${NATIVES_DIR}/windows-x86/"
else
  echo "SKIP: windows-x86 (i686-w64-mingw32-gcc not found)"
fi

# windows-x86_64 (MinGW cross-compile)
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "Building plugin: windows-x86_64..."
  (cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target x86_64-pc-windows-gnu)
  mkdir -p "${NATIVES_DIR}/windows-x86_64"
  cp "${CARGO_TARGET_DIR}/x86_64-pc-windows-gnu/release/volvoxgrid_plugin.dll" "${NATIVES_DIR}/windows-x86_64/"
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
  echo "Building plugin: macos-x86_64..."
  (cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target x86_64-apple-darwin)
  mkdir -p "${NATIVES_DIR}/macos-x86_64"
  cp "${CARGO_TARGET_DIR}/x86_64-apple-darwin/release/libvolvoxgrid_plugin.dylib" "${NATIVES_DIR}/macos-x86_64/"

  echo "Building plugin: macos-aarch64..."
  (cd "${PLUGIN_CRATE}" && cargo build -j "${CARGO_BUILD_JOBS}" --release --target aarch64-apple-darwin)
  mkdir -p "${NATIVES_DIR}/macos-aarch64"
  cp "${CARGO_TARGET_DIR}/aarch64-apple-darwin/release/libvolvoxgrid_plugin.dylib" "${NATIVES_DIR}/macos-aarch64/"
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
  <description>VolvoxGrid pixel-rendering grid engine for desktop (Linux, macOS, Windows)</description>
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
if should_build_dotnet; then
  echo ""
  echo "Building .NET WinForms artifacts (release, net40, x64+x86)..."
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
  mkdir -p "${DOTNET_STAGE_OUT_X64}" "${DOTNET_STAGE_OUT_X86}"
  cp -a "${DOTNET_STAGE_DIR_X64}/." "${DOTNET_STAGE_OUT_X64}/"
  cp -a "${DOTNET_STAGE_DIR_X86}/." "${DOTNET_STAGE_OUT_X86}/"
fi

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
fi
