Pod::Spec.new do |s|
  s.name             = 'volvoxgrid'
  s.version          = '0.8.2'
  s.summary          = 'VolvoxGrid pixel-rendering grid engine for Flutter'
  s.homepage         = 'https://github.com/ivere27/volvoxgrid'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = 'ivere27'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.static_framework = true

  # Auto-download xcframework from GitHub releases during pod install
  framework_dir = File.join(__dir__, 'Frameworks')
  xcframework_dir = File.join(framework_dir, 'VolvoxGridPlugin.xcframework')
  unless File.directory?(xcframework_dir)
    version = s.version.to_s
    url = "https://github.com/ivere27/volvoxgrid/releases/download/v#{version}/VolvoxGridPlugin.xcframework.zip"
    Pod::UI.puts "Downloading VolvoxGridPlugin.xcframework v#{version}..."
    FileUtils.mkdir_p(framework_dir)
    system("curl", "-L", "-o", "#{framework_dir}/VolvoxGridPlugin.xcframework.zip", url)
    system("unzip", "-o", "#{framework_dir}/VolvoxGridPlugin.xcframework.zip", "-d", framework_dir)
    File.delete("#{framework_dir}/VolvoxGridPlugin.xcframework.zip") rescue nil
  end

  s.vendored_frameworks = 'Frameworks/VolvoxGridPlugin.xcframework'
end
