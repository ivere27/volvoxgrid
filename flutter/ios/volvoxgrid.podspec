Pod::Spec.new do |s|
  s.name             = 'volvoxgrid'
  s.version          = '0.8.11'
  s.summary          = 'VolvoxGrid pixel-rendering grid engine for Flutter'
  s.homepage         = 'https://github.com/ivere27/volvoxgrid'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'ivere27'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.deployment_target = '13.0'
  s.static_framework = true

  # Auto-download xcframework from GitHub releases during pod install
  variant = ENV['VOLVOXGRID_VARIANT'].to_s.strip
  lite = variant == 'lite'
  framework_dir = File.join(__dir__, 'Frameworks')
  framework_name = lite ? 'VolvoxGridLite.xcframework' : 'VolvoxGrid.xcframework'
  zip_name = "#{framework_name}.zip"
  xcframework_dir = File.join(framework_dir, framework_name)
  unless File.directory?(xcframework_dir)
    version = ENV['VOLVOXGRID_VERSION'].to_s.strip
    version = s.version.to_s if version.empty?
    url = "https://github.com/ivere27/volvoxgrid/releases/download/v#{version}/#{zip_name}"
    Pod::UI.puts "Downloading #{framework_name} v#{version}..."
    FileUtils.mkdir_p(framework_dir)
    zip_path = File.join(framework_dir, zip_name)
    raise "Failed to download #{url}" unless system("curl", "-fL", "-o", zip_path, url)
    raise "Failed to unzip #{zip_path}" unless system("unzip", "-o", zip_path, "-d", framework_dir)
    File.delete(zip_path) rescue nil
  end

  s.vendored_frameworks = "Frameworks/#{framework_name}"
  s.frameworks = 'CoreFoundation', 'CoreGraphics', 'CoreText'
  s.dependency 'Flutter'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
