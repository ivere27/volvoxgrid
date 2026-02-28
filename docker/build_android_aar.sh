#!/usr/bin/env bash
set -euo pipefail

# Android AAR packaging script — runs inside Docker (Dockerfile.android).
#
# Builds the Rust volvoxgrid plugin for Android ABIs via cargo-ndk,
# then assembles a release AAR via Gradle with all JNI .so files included.
# Outputs Maven-ready artifacts: AAR, POM, sources.jar, javadoc.jar.
#
# Usage (inside Docker): VERSION=0.1.0 /opt/volvoxgrid/build_android_aar.sh

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
VERSION="${VERSION:-0.1.0}"
GROUP_ID="${GROUP_ID:-io.github.ivere27}"
ARTIFACT_ID="${ARTIFACT_ID:-volvoxgrid-android}"
ANDROID_ABIS="${ANDROID_ABIS:-arm64-v8a,armeabi-v7a}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/maven}"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_SDK_ROOT}/ndk/28.2.13676358}"

for required in \
  "${REPO_ROOT}/plugin/Cargo.toml" \
  "${REPO_ROOT}/android/gradlew" \
  "${REPO_ROOT}/android/volvoxgrid-android/build.gradle.kts"; do
  if [[ ! -f "${required}" ]]; then
    echo "Error: missing required file: ${required}" >&2
    exit 1
  fi
done

IFS=',' read -r -a ABI_LIST <<< "${ANDROID_ABIS}"
ANDROID_JNI_DIR="${REPO_ROOT}/android/volvoxgrid-android/src/main/jniLibs"

# ── Build Rust plugin .so for each ABI ──────────────────────────────────────
rm -rf "${ANDROID_JNI_DIR}"
echo "Building Rust plugin for Android ABIs: ${ANDROID_ABIS}..."

NDK_TARGETS=""
for ABI in "${ABI_LIST[@]}"; do
  ABI="${ABI//[[:space:]]/}"
  [[ -n "${ABI}" ]] || continue
  NDK_TARGETS="${NDK_TARGETS} -t ${ABI}"
done

(
  cd "${REPO_ROOT}/plugin"
  cargo ndk ${NDK_TARGETS} -o "${ANDROID_JNI_DIR}" build --release
)

for ABI in "${ABI_LIST[@]}"; do
  ABI="${ABI//[[:space:]]/}"
  SO_FILE="${ANDROID_JNI_DIR}/${ABI}/libvolvoxgrid_plugin.so"
  if [[ ! -f "${SO_FILE}" ]]; then
    echo "Error: expected .so not found: ${SO_FILE}" >&2
    exit 1
  fi
  echo "  ${ABI}: $(stat -c%s "${SO_FILE}") bytes"
done

# ── Build AAR via Gradle ────────────────────────────────────────────────────
echo "Building Android AAR (release)..."
"${REPO_ROOT}/android/gradlew" -p "${REPO_ROOT}/android" --no-daemon :volvoxgrid-android:assembleRelease

AAR_SRC="${REPO_ROOT}/android/volvoxgrid-android/build/outputs/aar/volvoxgrid-android-release.aar"
if [[ ! -f "${AAR_SRC}" ]]; then
  echo "Error: expected AAR not found at ${AAR_SRC}" >&2
  exit 1
fi

# ── Copy artifacts to dist/maven/ ───────────────────────────────────────────
mkdir -p "${DIST_DIR}"

AAR_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}.aar"
cp -f "${AAR_SRC}" "${AAR_OUT}"

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
  <packaging>aar</packaging>
  <name>${ARTIFACT_ID}</name>
  <description>VolvoxGrid pixel-rendering grid engine for Android</description>
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
      <artifactId>synurang-android</artifactId>
      <version>0.5.2</version>
    </dependency>
    <dependency>
      <groupId>com.google.protobuf</groupId>
      <artifactId>protobuf-javalite</artifactId>
      <version>3.25.1</version>
    </dependency>
  </dependencies>
</project>
POM

# ── Generate placeholder sources.jar and javadoc.jar ────────────────────────
WORK_DIR="$(mktemp -d /tmp/volvoxgrid-aar-XXXXXX)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

SOURCES_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}-sources.jar"
JAVADOC_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}-javadoc.jar"

# Sources jar: include Java/Kotlin sources if available
JAVA_SRC_DIR="${REPO_ROOT}/android/volvoxgrid-android/src/main/java"
KOTLIN_SRC_DIR="${REPO_ROOT}/android/volvoxgrid-android/src/main/kotlin"
SOURCES_DIR="${WORK_DIR}/sources"
mkdir -p "${SOURCES_DIR}"
if [[ -d "${JAVA_SRC_DIR}" ]]; then
  cp -r "${JAVA_SRC_DIR}/." "${SOURCES_DIR}/"
fi
if [[ -d "${KOTLIN_SRC_DIR}" ]]; then
  cp -r "${KOTLIN_SRC_DIR}/." "${SOURCES_DIR}/"
fi
(cd "${SOURCES_DIR}" && jar cf "${SOURCES_OUT}" .)

# Javadoc jar: empty placeholder
JAVADOC_DIR="${WORK_DIR}/javadoc"
mkdir -p "${JAVADOC_DIR}"
(cd "${JAVADOC_DIR}" && jar cf "${JAVADOC_OUT}" .)

echo ""
echo "Built Android AAR artifacts:"
echo "  ${AAR_OUT}"
echo "  ${POM_OUT}"
echo "  ${SOURCES_OUT}"
echo "  ${JAVADOC_OUT}"
