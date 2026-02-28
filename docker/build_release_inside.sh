#!/usr/bin/env bash
set -euo pipefail

BUILD_MODE="${BUILD_MODE:-${1:-gpu}}"
REPO_ROOT="${REPO_ROOT:-$(pwd)}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-${REPO_ROOT}/target}"
DEFAULT_DIST_ROOT="${REPO_ROOT}/dist/docker/${BUILD_MODE}"
if [[ "${BUILD_MODE}" == "all" ]]; then
  DEFAULT_DIST_ROOT="${REPO_ROOT}/dist/docker"
fi
DIST_ROOT="${DIST_ROOT:-${DEFAULT_DIST_ROOT}}"

case "${BUILD_MODE}" in
  cpu|gpu|all) ;;
  *)
    echo "Error: BUILD_MODE must be 'cpu', 'gpu', or 'all', got '${BUILD_MODE}'." >&2
    exit 1
    ;;
esac

for required in \
  "${REPO_ROOT}/plugin/Cargo.toml" \
  "${REPO_ROOT}/android/gradlew" \
  "${REPO_ROOT}/android/volvoxgrid-android/build.gradle.kts" \
  "${REPO_ROOT}/web/crate/Cargo.toml"; do
  if [[ ! -f "${required}" ]]; then
    echo "Error: missing required file: ${required}" >&2
    exit 1
  fi
done

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_SDK_ROOT}/ndk/28.2.13676358}"

build_one_mode() {
  local mode="$1"
  local mode_dist_root="$2"
  local -a plugin_feature_args=(--no-default-features)
  local -a wasm_feature_args=()
  local android_jni_dist="${mode_dist_root}/android/jniLibs"
  local android_jni_module="${REPO_ROOT}/android/volvoxgrid-android/src/main/jniLibs"
  local flutter_android_jni_module="${REPO_ROOT}/flutter/android/src/main/jniLibs"

  if [[ "${mode}" == "gpu" ]]; then
    plugin_feature_args+=(--features gpu)
    wasm_feature_args+=(--features gpu)
  fi

  rm -rf "${mode_dist_root}"
  mkdir -p "${mode_dist_root}"

  echo "Building Android plugin .so files (${mode}, release)..."
  (
    cd "${REPO_ROOT}/plugin"
    cargo ndk \
      -t arm64-v8a \
      -t armeabi-v7a \
      -o "${android_jni_dist}" \
      build --release "${plugin_feature_args[@]}"
  )

  rm -rf "${android_jni_module}" "${flutter_android_jni_module}"
  mkdir -p "${android_jni_module}" "${flutter_android_jni_module}"
  cp -a "${android_jni_dist}/." "${android_jni_module}/"
  cp -a "${android_jni_dist}/." "${flutter_android_jni_module}/"

  mkdir -p "${mode_dist_root}/flutter/android/jniLibs"
  cp -a "${android_jni_dist}/." "${mode_dist_root}/flutter/android/jniLibs/"

  echo "Building Android AAR (${mode}, release)..."
  "${REPO_ROOT}/android/gradlew" -p "${REPO_ROOT}/android" --no-daemon :volvoxgrid-android:assembleRelease

  local aar_src="${REPO_ROOT}/android/volvoxgrid-android/build/outputs/aar/volvoxgrid-android-release.aar"
  if [[ ! -f "${aar_src}" ]]; then
    echo "Error: expected AAR not found at ${aar_src}" >&2
    exit 1
  fi

  mkdir -p "${mode_dist_root}/android/aar"
  cp -f "${aar_src}" "${mode_dist_root}/android/aar/"

  echo "Building Linux x64 plugin .so (${mode}, release)..."
  (
    cd "${REPO_ROOT}/plugin"
    cargo build --release "${plugin_feature_args[@]}"
  )

  local linux_so_src="${CARGO_TARGET_DIR}/release/libvolvoxgrid_plugin.so"
  if [[ ! -f "${linux_so_src}" ]]; then
    echo "Error: expected Linux plugin .so not found at ${linux_so_src}" >&2
    exit 1
  fi

  local flutter_linux_module_dir="${REPO_ROOT}/flutter/linux/x64"
  mkdir -p "${flutter_linux_module_dir}" "${mode_dist_root}/flutter/linux/x64"
  cp -f "${linux_so_src}" "${flutter_linux_module_dir}/libvolvoxgrid_plugin.so"
  cp -f "${linux_so_src}" "${mode_dist_root}/flutter/linux/x64/libvolvoxgrid_plugin.so"

  echo "Building wasm package (${mode}, release)..."
  mkdir -p "${mode_dist_root}/wasm"
  (
    cd "${REPO_ROOT}/web/crate"
    rustup run nightly wasm-pack build . --release --target web --out-dir "${mode_dist_root}/wasm" "${wasm_feature_args[@]}"
  )

  {
    echo "build_mode=${mode}"
    echo "plugin_features=${plugin_feature_args[*]}"
    if [[ "${#wasm_feature_args[@]}" -eq 0 ]]; then
      echo "wasm_features=none"
    else
      echo "wasm_features=${wasm_feature_args[*]}"
    fi
    echo "android_ndk=${ANDROID_NDK_HOME}"
    echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    find "${mode_dist_root}" -type f -printf "%P\t%s bytes\n" | sort
  } > "${mode_dist_root}/manifest.txt"

  echo
  echo "Completed mode '${mode}'. Artifacts: ${mode_dist_root}"
}

if [[ "${BUILD_MODE}" == "all" ]]; then
  mkdir -p "${DIST_ROOT}"
  build_one_mode gpu "${DIST_ROOT}/gpu"
  build_one_mode cpu "${DIST_ROOT}/cpu"

  {
    echo "build_mode=all"
    echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    find "${DIST_ROOT}" -type f -printf "%P\t%s bytes\n" | sort
  } > "${DIST_ROOT}/manifest.txt"

  echo
  echo "Build completed for gpu+cpu."
  echo "Artifacts: ${DIST_ROOT}"
else
  build_one_mode "${BUILD_MODE}" "${DIST_ROOT}"
  echo
  echo "Build completed."
  echo "Artifacts: ${DIST_ROOT}"
fi
