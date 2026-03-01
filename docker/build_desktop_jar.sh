#!/usr/bin/env bash
set -euo pipefail

# Desktop JAR packaging script — runs inside Docker (Dockerfile.desktop).
#
# Cross-compiles the Rust volvoxgrid plugin for linux-x86_64, linux-x86,
# linux-aarch64, linux-armv7, windows-x86_64, macos-x86_64, macos-aarch64,
# then packages a fat JAR
# with classes from volvoxgrid-java-common + embedded native/ libraries.
#
# Usage (inside Docker): VERSION=0.1.0 /opt/volvoxgrid/build_desktop_jar.sh

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
VERSION="${VERSION:-0.1.0}"
GROUP_ID="${GROUP_ID:-io.github.ivere27}"
ARTIFACT_ID="${ARTIFACT_ID:-volvoxgrid-desktop}"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/maven}"

WORK_DIR="$(mktemp -d /tmp/volvoxgrid-desktop-XXXXXX)"
NATIVES_DIR="${WORK_DIR}/natives"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

PLUGIN_CRATE="${REPO_ROOT}/plugin"
if [[ ! -f "${PLUGIN_CRATE}/Cargo.toml" ]]; then
  echo "Error: plugin crate not found at ${PLUGIN_CRATE}" >&2
  exit 1
fi

# ── Generate .cargo/config.toml for cross-compilation linkers ───────────────
CARGO_CONFIG_DIR="${REPO_ROOT}/.cargo"
CARGO_CONFIG="${CARGO_CONFIG_DIR}/config.toml"
# Back up existing config if present
if [[ -f "${CARGO_CONFIG}" ]]; then
  cp "${CARGO_CONFIG}" "${CARGO_CONFIG}.bak"
fi

cat > "${CARGO_CONFIG}" <<CARGO
[build]
target-dir = "${CARGO_TARGET_DIR}"

[target.i686-unknown-linux-gnu]
linker = "i686-linux-gnu-gcc"

[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.armv7-unknown-linux-gnueabihf]
linker = "arm-linux-gnueabihf-gcc"

[target.i686-pc-windows-gnu]
linker = "i686-w64-mingw32-gcc"

[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"

[target.x86_64-apple-darwin]
linker = "/opt/volvoxgrid/zig-cc-x86_64-macos.sh"

[target.aarch64-apple-darwin]
linker = "/opt/volvoxgrid/zig-cc-aarch64-macos.sh"
CARGO

# ── Cross-compile Rust plugin for each platform ────────────────────────────

# linux-x86_64 (native)
echo "Building plugin: linux-x86_64..."
(cd "${PLUGIN_CRATE}" && cargo build --release --target x86_64-unknown-linux-gnu)
mkdir -p "${NATIVES_DIR}/linux-x86_64"
cp "${CARGO_TARGET_DIR}/x86_64-unknown-linux-gnu/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-x86_64/"

# linux-x86 (cross-compile)
if command -v i686-linux-gnu-gcc >/dev/null 2>&1; then
  echo "Building plugin: linux-x86..."
  (cd "${PLUGIN_CRATE}" && cargo build --release --target i686-unknown-linux-gnu)
  mkdir -p "${NATIVES_DIR}/linux-x86"
  cp "${CARGO_TARGET_DIR}/i686-unknown-linux-gnu/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-x86/"
else
  echo "SKIP: linux-x86 (i686-linux-gnu-gcc not found)"
fi

# linux-aarch64 (cross-compile)
if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
  echo "Building plugin: linux-aarch64..."
  (cd "${PLUGIN_CRATE}" && cargo build --release --target aarch64-unknown-linux-gnu)
  mkdir -p "${NATIVES_DIR}/linux-aarch64"
  cp "${CARGO_TARGET_DIR}/aarch64-unknown-linux-gnu/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-aarch64/"
else
  echo "SKIP: linux-aarch64 (aarch64-linux-gnu-gcc not found)"
fi

# linux-armv7 (cross-compile)
if command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
  echo "Building plugin: linux-armv7..."
  (cd "${PLUGIN_CRATE}" && cargo build --release --target armv7-unknown-linux-gnueabihf)
  mkdir -p "${NATIVES_DIR}/linux-armv7"
  cp "${CARGO_TARGET_DIR}/armv7-unknown-linux-gnueabihf/release/libvolvoxgrid_plugin.so" "${NATIVES_DIR}/linux-armv7/"
else
  echo "SKIP: linux-armv7 (arm-linux-gnueabihf-gcc not found)"
fi

# windows-x86 (MinGW cross-compile)
if command -v i686-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "Building plugin: windows-x86..."
  (cd "${PLUGIN_CRATE}" && cargo build --release --target i686-pc-windows-gnu)
  mkdir -p "${NATIVES_DIR}/windows-x86"
  cp "${CARGO_TARGET_DIR}/i686-pc-windows-gnu/release/volvoxgrid_plugin.dll" "${NATIVES_DIR}/windows-x86/"
else
  echo "SKIP: windows-x86 (i686-w64-mingw32-gcc not found)"
fi

# windows-x86_64 (MinGW cross-compile)
if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  echo "Building plugin: windows-x86_64..."
  (cd "${PLUGIN_CRATE}" && cargo build --release --target x86_64-pc-windows-gnu)
  mkdir -p "${NATIVES_DIR}/windows-x86_64"
  cp "${CARGO_TARGET_DIR}/x86_64-pc-windows-gnu/release/volvoxgrid_plugin.dll" "${NATIVES_DIR}/windows-x86_64/"
else
  echo "SKIP: windows-x86_64 (x86_64-w64-mingw32-gcc not found)"
fi

# macos-x86_64 (zig cross-compile)
if command -v zig >/dev/null 2>&1; then
  echo "Building plugin: macos-x86_64..."
  (cd "${PLUGIN_CRATE}" && cargo build --release --target x86_64-apple-darwin)
  mkdir -p "${NATIVES_DIR}/macos-x86_64"
  cp "${CARGO_TARGET_DIR}/x86_64-apple-darwin/release/libvolvoxgrid_plugin.dylib" "${NATIVES_DIR}/macos-x86_64/"

  echo "Building plugin: macos-aarch64..."
  (cd "${PLUGIN_CRATE}" && cargo build --release --target aarch64-apple-darwin)
  mkdir -p "${NATIVES_DIR}/macos-aarch64"
  cp "${CARGO_TARGET_DIR}/aarch64-apple-darwin/release/libvolvoxgrid_plugin.dylib" "${NATIVES_DIR}/macos-aarch64/"
else
  echo "SKIP: macos-x86_64, macos-aarch64 (zig not found)"
fi

# ── Restore .cargo/config.toml ──────────────────────────────────────────────
if [[ -f "${CARGO_CONFIG}.bak" ]]; then
  mv "${CARGO_CONFIG}.bak" "${CARGO_CONFIG}"
else
  # Restore minimal config
  cat > "${CARGO_CONFIG}" <<'CARGO'
[build]
target-dir = "target"
CARGO
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
gradle -p "${JAVA_COMMON_DIR}" --no-daemon -I "${GRADLE_REPO_INIT}" clean jar

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
      <version>0.5.2</version>
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

echo ""
echo "Built desktop JAR artifacts:"
echo "  ${JAR_OUT}"
echo "  ${POM_OUT}"
echo "  ${SOURCES_OUT}"
echo "  ${JAVADOC_OUT}"
