require_relative '../native/resolve'

Pod::Spec.new do |s|
  s.name             = 'volvoxgrid'
  s.version          = VolvoxGridNative.package_version
  s.summary          = 'VolvoxGrid pixel-rendering grid engine for Flutter'
  s.homepage         = 'https://github.com/ivere27/volvoxgrid'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'ivere27'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.deployment_target = '13.0'
  s.static_framework = true

  # Published iOS assets live on GitHub; source=maven means published mode
  # consistently with the other platforms. Local mode never downloads.
  framework_name = ENV['VOLVOXGRID_VARIANT'] == 'lite' ? 'VolvoxGridLite.xcframework' : 'VolvoxGrid.xcframework'
  VolvoxGridNative.ios_framework(framework_name)

  s.vendored_frameworks = "Frameworks/#{framework_name}"
  s.frameworks = 'CoreFoundation', 'CoreGraphics', 'CoreText'
  s.dependency 'Flutter'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
