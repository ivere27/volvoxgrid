require_relative '../native/resolve'
VolvoxGridNative.macos_library

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint volvoxgrid.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'volvoxgrid'
  s.version          = VolvoxGridNative.package_version
  s.summary          = 'VolvoxGrid pixel-rendering grid widget for Flutter.'
  s.description      = <<-DESC
VolvoxGrid pixel-rendering grid widget for Flutter.
                       DESC
  s.homepage         = 'https://github.com/ivere27/volvoxgrid'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'VolvoxGrid' => 'opensource@volvoxgrid.dev' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.vendored_libraries = 'x64/libvolvoxgrid.dylib'

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  s.swift_version = '5.0'

end
