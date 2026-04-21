#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint volvoxgrid.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'volvoxgrid'
  s.version          = '0.7.1'
  s.summary          = 'VolvoxGrid pixel-rendering grid widget for Flutter.'
  s.description      = <<-DESC
VolvoxGrid pixel-rendering grid widget for Flutter.
                       DESC
  s.homepage         = 'https://github.com/ivere27/volvoxgrid'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'VolvoxGrid' => 'opensource@volvoxgrid.dev' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.vendored_libraries = 'x64/libvolvoxgrid_plugin.dylib'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  s.swift_version = '5.0'

  s.script_phase = {
    :name => 'VolvoxGrid Resolve Native',
    :execution_position => :before_compile,
    :script => <<-SCRIPT
set -eu
PACKAGE_ROOT="${PODS_TARGET_SRCROOT}"
PLUGIN_ROOT="${PACKAGE_ROOT}/.."
VOLVOXGRID_SOURCE="${VOLVOXGRID_SOURCE:-maven}"
VOLVOXGRID_VERSION="${VOLVOXGRID_VERSION:-0.7.1}"

if [ "${VOLVOXGRID_SOURCE}" != "maven" ]; then
  exit 0
fi

GRADLE_DIR="${PACKAGE_ROOT}"
EXTRA_ARGS=""
case "${VOLVOXGRID_VERSION}" in
  *-SNAPSHOT) EXTRA_ARGS="--refresh-dependencies" ;;
esac

if [ -x "${PLUGIN_ROOT}/android/gradlew" ]; then
  "${PLUGIN_ROOT}/android/gradlew" -p "${GRADLE_DIR}" -PvolvoxgridVersion="${VOLVOXGRID_VERSION}" ${EXTRA_ARGS} copyNative
elif command -v gradle >/dev/null 2>&1; then
  gradle -p "${GRADLE_DIR}" -PvolvoxgridVersion="${VOLVOXGRID_VERSION}" ${EXTRA_ARGS} copyNative
else
  echo "error: VolvoxGrid requires gradle (or android/gradlew) to resolve desktop binaries from Maven."
  exit 1
fi
SCRIPT
  }
end
