#!/usr/bin/env bash
set -euo pipefail

# Android AAR packaging script — runs inside Docker (Dockerfile.android).
#
# Builds the Rust volvoxgrid plugin for Android ABIs via cargo-ndk,
# assembles a release AAR via Gradle with all JNI .so files included,
# then merges volvoxgrid-java-common classes into classes.jar (fat AAR).
# Outputs Maven-ready artifacts: AAR, POM, sources.jar, javadoc.jar.
#
# Usage (inside Docker): VERSION=0.1.2 /opt/volvoxgrid/build_android_aar.sh
# Optional: PLUGIN_BUILD_MODE=lite (default: full)

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
VERSION="${VERSION:-0.1.2}"
GROUP_ID="${GROUP_ID:-io.github.ivere27}"
ARTIFACT_ID="${ARTIFACT_ID:-volvoxgrid-android}"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
PLUGIN_BUILD_MODE="${PLUGIN_BUILD_MODE:-full}"
ANDROID_ABIS="${ANDROID_ABIS:-arm64-v8a,armeabi-v7a}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/maven}"

case "${PLUGIN_BUILD_MODE}" in
  full|lite) ;;
  *)
    echo "Error: PLUGIN_BUILD_MODE must be 'full' or 'lite', got '${PLUGIN_BUILD_MODE}'." >&2
    exit 1
    ;;
esac

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
NORMALIZED_ABIS=()
for ABI in "${ABI_LIST[@]}"; do
  ABI="${ABI//[[:space:]]/}"
  [[ -n "${ABI}" ]] || continue
  NORMALIZED_ABIS+=("${ABI}")
done
ABI_LIST=("${NORMALIZED_ABIS[@]}")

JNI_STAGE_DIR="$(mktemp -d /tmp/volvoxgrid-android-jni-XXXXXX)"
ANDROID_JNI_DIR="${JNI_STAGE_DIR}/jniLibs"
# Full Android AAR should include GPU backend support.
PLUGIN_FEATURE_ARGS=(--release --features gpu)
AAR_PLUGIN_SO_NAME="libvolvoxgrid_plugin.so"
if [[ "${PLUGIN_BUILD_MODE}" == "lite" ]]; then
  PLUGIN_FEATURE_ARGS=(--release --no-default-features --features demo)
  AAR_PLUGIN_SO_NAME="libvolvoxgrid_plugin_lite.so"
fi

# ── Build Rust plugin .so for each ABI ──────────────────────────────────────
echo "Building Rust plugin for Android ABIs: ${ANDROID_ABIS} (mode=${PLUGIN_BUILD_MODE})..."

NDK_TARGETS=""
for ABI in "${ABI_LIST[@]}"; do
  ABI="${ABI//[[:space:]]/}"
  [[ -n "${ABI}" ]] || continue
  NDK_TARGETS="${NDK_TARGETS} -t ${ABI}"
done

(
  cd "${REPO_ROOT}/plugin"
  cargo ndk ${NDK_TARGETS} -o "${ANDROID_JNI_DIR}" build "${PLUGIN_FEATURE_ARGS[@]}"
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
# Gradle/AGP stores absolute source paths in native build metadata under
# .cxx and build/intermediates/cxx. When reusing a workspace across host and
# Docker, those cached paths can become invalid and break configureCMake.
rm -rf \
  "${REPO_ROOT}/android/volvoxgrid-android/.cxx" \
  "${REPO_ROOT}/android/volvoxgrid-android/build/intermediates/cxx" \
  "${REPO_ROOT}/android/volvoxgrid-android/build/.cxx"
"${REPO_ROOT}/android/gradlew" -p "${REPO_ROOT}/android" --no-daemon \
  -PvolvoxgridVersion="${VERSION}" \
  -PvolvoxgridGitCommit="${GIT_COMMIT}" \
  -PvolvoxgridBuildDate="${BUILD_DATE}" \
  :volvoxgrid-android:assembleRelease

AAR_SRC="${REPO_ROOT}/android/volvoxgrid-android/build/outputs/aar/volvoxgrid-android-release.aar"
if [[ ! -f "${AAR_SRC}" ]]; then
  echo "Error: expected AAR not found at ${AAR_SRC}" >&2
  exit 1
fi

# ── Build java-common and merge into AAR (fat AAR) ──────────────────────────
JAVA_COMMON_DIR="${REPO_ROOT}/java/common"
if [[ ! -d "${JAVA_COMMON_DIR}" ]]; then
  echo "Error: java/common not found at ${JAVA_COMMON_DIR}" >&2
  exit 1
fi

echo "Building volvoxgrid-java-common JAR for fat AAR..."
"${REPO_ROOT}/android/gradlew" -p "${JAVA_COMMON_DIR}" --no-daemon clean jar
COMMON_JAR="$(find "${JAVA_COMMON_DIR}/build/libs" -maxdepth 1 -type f -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | head -n 1)"
if [[ -z "${COMMON_JAR}" || ! -f "${COMMON_JAR}" ]]; then
  echo "Error: volvoxgrid-java-common jar build failed." >&2
  exit 1
fi

MERGE_WORK_DIR="$(mktemp -d /tmp/volvoxgrid-aar-merge-XXXXXX)"

AAR_UNPACKED_DIR="${MERGE_WORK_DIR}/aar"
CLASSES_WORK_DIR="${MERGE_WORK_DIR}/classes"
mkdir -p "${AAR_UNPACKED_DIR}" "${CLASSES_WORK_DIR}"

unzip -q "${AAR_SRC}" -d "${AAR_UNPACKED_DIR}"
if [[ ! -f "${AAR_UNPACKED_DIR}/classes.jar" ]]; then
  echo "Error: classes.jar not found inside ${AAR_SRC}" >&2
  exit 1
fi

# Keep only requested ABIs in the output AAR JNI folder.
if [[ -d "${AAR_UNPACKED_DIR}/jni" ]]; then
  for ABI_DIR in "${AAR_UNPACKED_DIR}/jni"/*; do
    [[ -d "${ABI_DIR}" ]] || continue
    ABI_NAME="$(basename "${ABI_DIR}")"
    KEEP_ABI=0
    for ABI in "${ABI_LIST[@]}"; do
      if [[ "${ABI}" == "${ABI_NAME}" ]]; then
        KEEP_ABI=1
        break
      fi
    done
    if [[ "${KEEP_ABI}" -eq 0 ]]; then
      rm -rf "${ABI_DIR}"
    fi
  done
fi

# Inject plugin native libs from temp staging dir into AAR jni/ layout.
for ABI in "${ABI_LIST[@]}"; do
  SRC_SO="${ANDROID_JNI_DIR}/${ABI}/libvolvoxgrid_plugin.so"
  if [[ ! -f "${SRC_SO}" ]]; then
    echo "Error: expected staged .so not found: ${SRC_SO}" >&2
    exit 1
  fi
  mkdir -p "${AAR_UNPACKED_DIR}/jni/${ABI}"
  # Ensure the packed AAR contains only the selected plugin variant.
  rm -f \
    "${AAR_UNPACKED_DIR}/jni/${ABI}/libvolvoxgrid_plugin.so" \
    "${AAR_UNPACKED_DIR}/jni/${ABI}/libvolvoxgrid_plugin_lite.so"
  cp -f "${SRC_SO}" "${AAR_UNPACKED_DIR}/jni/${ABI}/${AAR_PLUGIN_SO_NAME}"
done

(cd "${CLASSES_WORK_DIR}" && jar xf "${AAR_UNPACKED_DIR}/classes.jar")
(cd "${CLASSES_WORK_DIR}" && jar xf "${COMMON_JAR}")
rm -rf "${CLASSES_WORK_DIR}/META-INF"
(cd "${CLASSES_WORK_DIR}" && jar cf "${AAR_UNPACKED_DIR}/classes.jar" .)

# ── Copy artifacts to dist/maven/ ───────────────────────────────────────────
mkdir -p "${DIST_DIR}"
AAR_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}.aar"
# `zip -r` updates existing archives and keeps entries not present in source.
# Remove any prior output first to avoid stale JNI libs from previous builds.
rm -f "${AAR_OUT}"
(cd "${AAR_UNPACKED_DIR}" && zip -qr "${AAR_OUT}" .)
rm -rf "${MERGE_WORK_DIR}"
rm -rf "${JNI_STAGE_DIR}"

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
      <version>0.5.3</version>
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
