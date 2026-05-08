#!/usr/bin/env bash
set -euo pipefail

# Android Compose AAR packaging script — runs inside Docker (Dockerfile.android).
#
# Builds the volvoxgrid-android-compose AAR (a thin Kotlin/Compose wrapper
# around volvoxgrid-android) and produces Maven-ready artifacts: AAR, POM,
# sources.jar, javadoc.jar.
#
# This module does NOT bundle native code — its POM declares a runtime
# dependency on volvoxgrid-android (which carries the JNI .so files).
#
# Usage (inside Docker): VERSION=0.8.6 /opt/volvoxgrid/build_android_compose_aar.sh

REPO_ROOT="${REPO_ROOT:-$(pwd)}"
VERSION="${VERSION:-0.8.6}"
GROUP_ID="${GROUP_ID:-io.github.ivere27}"
ARTIFACT_ID="${ARTIFACT_ID:-volvoxgrid-android-compose}"
PARENT_ARTIFACT_ID="${PARENT_ARTIFACT_ID:-volvoxgrid-android}"
PARENT_GROUP_ID="${PARENT_GROUP_ID:-${GROUP_ID}}"
COMPOSE_UI_VERSION="${COMPOSE_UI_VERSION:-1.6.8}"
COMPOSE_RUNTIME_VERSION="${COMPOSE_RUNTIME_VERSION:-1.6.8}"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist/maven}"

detect_cpu_count() {
  if command -v nproc >/dev/null 2>&1; then nproc; return; fi
  if command -v getconf >/dev/null 2>&1; then getconf _NPROCESSORS_ONLN; return; fi
  echo 1
}
CPU_COUNT="$(detect_cpu_count)"
DEFAULT_BUILD_JOBS=$(( CPU_COUNT > 2 ? CPU_COUNT - 2 : 1 ))
BUILD_JOBS="${BUILD_JOBS:-${DEFAULT_BUILD_JOBS}}"
GRADLE_MAX_WORKERS="${GRADLE_MAX_WORKERS:-${BUILD_JOBS}}"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"

ANDROID_LOCAL_PROPERTIES="${REPO_ROOT}/android/local.properties"
ANDROID_LOCAL_PROPERTIES_BACKUP=""
restore_android_local_properties() {
  if [[ -n "${ANDROID_LOCAL_PROPERTIES_BACKUP}" && -f "${ANDROID_LOCAL_PROPERTIES_BACKUP}" ]]; then
    cp "${ANDROID_LOCAL_PROPERTIES_BACKUP}" "${ANDROID_LOCAL_PROPERTIES}"
    rm -f "${ANDROID_LOCAL_PROPERTIES_BACKUP}"
    return
  fi
  rm -f "${ANDROID_LOCAL_PROPERTIES}"
}
prepare_android_local_properties() {
  if [[ -f "${ANDROID_LOCAL_PROPERTIES}" ]]; then
    ANDROID_LOCAL_PROPERTIES_BACKUP="$(mktemp /tmp/volvoxgrid-android-local-properties-XXXXXX)"
    cp "${ANDROID_LOCAL_PROPERTIES}" "${ANDROID_LOCAL_PROPERTIES_BACKUP}"
  fi
  printf 'sdk.dir=%s\n' "${ANDROID_SDK_ROOT}" > "${ANDROID_LOCAL_PROPERTIES}"
}
trap restore_android_local_properties EXIT
prepare_android_local_properties

for required in \
  "${REPO_ROOT}/android/gradlew" \
  "${REPO_ROOT}/android/volvoxgrid-android-compose/build.gradle.kts"; do
  if [[ ! -f "${required}" ]]; then
    echo "Error: missing required file: ${required}" >&2
    exit 1
  fi
done

echo "Building Android Compose AAR (version ${VERSION})..."
"${REPO_ROOT}/android/gradlew" -p "${REPO_ROOT}/android" --no-daemon \
  --max-workers="${GRADLE_MAX_WORKERS}" \
  -PvolvoxgridVersion="${VERSION}" \
  -PvolvoxgridGitCommit="${GIT_COMMIT}" \
  -PvolvoxgridBuildDate="${BUILD_DATE}" \
  ":volvoxgrid-android-compose:assembleRelease"

AAR_SRC="${REPO_ROOT}/android/volvoxgrid-android-compose/build/outputs/aar/volvoxgrid-android-compose-release.aar"
if [[ ! -f "${AAR_SRC}" ]]; then
  echo "Error: expected AAR not found at ${AAR_SRC}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
AAR_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}.aar"
cp -f "${AAR_SRC}" "${AAR_OUT}"

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
  <description>VolvoxGrid Jetpack Compose wrapper for the Android engine</description>
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
      <groupId>${PARENT_GROUP_ID}</groupId>
      <artifactId>${PARENT_ARTIFACT_ID}</artifactId>
      <version>${VERSION}</version>
      <type>aar</type>
    </dependency>
    <dependency>
      <groupId>androidx.compose.ui</groupId>
      <artifactId>ui</artifactId>
      <version>${COMPOSE_UI_VERSION}</version>
    </dependency>
    <dependency>
      <groupId>androidx.compose.runtime</groupId>
      <artifactId>runtime</artifactId>
      <version>${COMPOSE_RUNTIME_VERSION}</version>
    </dependency>
  </dependencies>
</project>
POM

WORK_DIR="$(mktemp -d /tmp/volvoxgrid-compose-aar-XXXXXX)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap 'cleanup; restore_android_local_properties' EXIT

SOURCES_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}-sources.jar"
JAVADOC_OUT="${DIST_DIR}/${ARTIFACT_ID}-${VERSION}-javadoc.jar"

KOTLIN_SRC_DIR="${REPO_ROOT}/android/volvoxgrid-android-compose/src/main/kotlin"
JAVA_SRC_DIR="${REPO_ROOT}/android/volvoxgrid-android-compose/src/main/java"
SOURCES_DIR="${WORK_DIR}/sources"
mkdir -p "${SOURCES_DIR}"
[[ -d "${KOTLIN_SRC_DIR}" ]] && cp -r "${KOTLIN_SRC_DIR}/." "${SOURCES_DIR}/"
[[ -d "${JAVA_SRC_DIR}" ]] && cp -r "${JAVA_SRC_DIR}/." "${SOURCES_DIR}/"
(cd "${SOURCES_DIR}" && jar cf "${SOURCES_OUT}" .)

JAVADOC_DIR="${WORK_DIR}/javadoc"
mkdir -p "${JAVADOC_DIR}"
(cd "${JAVADOC_DIR}" && jar cf "${JAVADOC_OUT}" .)

echo ""
echo "Built Android Compose AAR artifacts:"
echo "  ${AAR_OUT}"
echo "  ${POM_OUT}"
echo "  ${SOURCES_OUT}"
echo "  ${JAVADOC_OUT}"
