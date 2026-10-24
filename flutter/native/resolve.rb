# Shared Apple package configuration. The pubspec is the package's version
# authority; an unrelated ancestor VERSION must never affect a pub consumer.
require 'fileutils'
require 'tmpdir'
module VolvoxGridNative
  PACKAGE_ROOT = File.expand_path('..', __dir__)
  REPO_ROOT = File.dirname(PACKAGE_ROOT)
  module_function

  def repository?
    File.file?(File.join(REPO_ROOT, 'Cargo.toml')) && File.directory?(File.join(REPO_ROOT, 'engine'))
  end

  def package_version
    pubspec = File.join(PACKAGE_ROOT, 'pubspec.yaml')
    version = File.read(pubspec)[/^version:\s*['"]?([^\s'"#]+)/, 1] if File.file?(pubspec)
    version = File.read(File.join(REPO_ROOT, 'VERSION')).strip if (version.nil? || version.empty?) && repository? && File.file?(File.join(REPO_ROOT, 'VERSION'))
    raise 'VolvoxGrid: Missing package version in pubspec.yaml.' if version.nil? || version.empty?
    version.split('+').first
  end

  def version
    value = ENV['VOLVOXGRID_VERSION'].to_s.strip
    value = package_version if value.empty?
    raise "VolvoxGrid: Invalid native version #{value.inspect}." unless value.match?(/\A[0-9][A-Za-z0-9._+\-]*\z/)
    value
  end

  def source
    value = ENV.fetch('VOLVOXGRID_SOURCE', 'maven').strip
    value = 'maven' if value.empty?
    raise "VolvoxGrid: Invalid VOLVOXGRID_SOURCE=#{value.inspect}; expected local or maven." unless %w[local maven].include?(value)
    value
  end

  def download(url, destination)
    raise "VolvoxGrid: Cannot download #{url}. Check network/proxy and VOLVOXGRID_VERSION; for offline builds use VOLVOXGRID_SOURCE=local with a prepared native library/framework." unless system('curl', '--fail', '--location', '--retry', '2', '--output', destination, url)
  end

  def macos_library
    destination = File.join(PACKAGE_ROOT, 'macos', 'x64', 'libvolvoxgrid.dylib')
    if source == 'local'
      explicit = ENV['VOLVOXGRID_LIBRARY'].to_s
      raise 'VolvoxGrid: Local lite builds require VOLVOXGRID_LIBRARY pointing to the lite native binary.' if ENV['VOLVOXGRID_VARIANT'] == 'lite' && explicit.empty?
      candidates = explicit.empty? ? [destination] : [explicit]
      candidates += %w[release debug].map { |mode| File.join(REPO_ROOT, 'target', mode, 'libvolvoxgrid.dylib') } if explicit.empty? && repository?
      library = candidates.find { |candidate| File.file?(candidate) }
      raise 'VolvoxGrid: No local libvolvoxgrid.dylib. Set VOLVOXGRID_LIBRARY, build the engine, or use VOLVOXGRID_SOURCE=maven.' unless library
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(library, destination) unless File.expand_path(library) == destination
      FileUtils.rm_f("#{destination}.source")
      return
    end
    arch = ENV['ARCHS'].to_s.split.first || `uname -m`.strip
    native_arch = { 'arm64' => 'macos-aarch64', 'aarch64' => 'macos-aarch64', 'x86_64' => 'macos-x86_64' }[arch]
    raise "VolvoxGrid: Unsupported macOS architecture #{arch}." unless native_arch
    group = ENV.fetch('VOLVOXGRID_GROUP', 'io.github.ivere27')
    artifact = ENV.fetch('VOLVOXGRID_ARTIFACT', ENV['VOLVOXGRID_VARIANT'] == 'lite' ? 'volvoxgrid-desktop-lite' : 'volvoxgrid-desktop')
    repository = ENV.fetch('VOLVOXGRID_MAVEN_REPOSITORY', 'https://repo.maven.apache.org/maven2')
    url = "#{repository}/#{group.tr('.', '/')}/#{artifact}/#{version}/#{artifact}-#{version}.jar"
    key = "#{url}/#{native_arch}"
    marker = "#{destination}.source"
    return if File.file?(destination) && File.file?(marker) && File.read(marker) == key
    Dir.mktmpdir('volvoxgrid-native') do |tmp|
      archive = File.join(tmp, 'native.jar')
      download(url, archive)
      member = "native/#{native_arch}/libvolvoxgrid.dylib"
      raise "VolvoxGrid: #{url} does not provide #{member}. Check version and architecture." unless system('unzip', '-j', '-o', archive, member, '-d', tmp)
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(File.join(tmp, 'libvolvoxgrid.dylib'), destination)
      File.write(marker, key)
    end
  end

  def ios_framework(framework_name)
    directory = File.join(PACKAGE_ROOT, 'ios', 'Frameworks')
    destination = File.join(directory, framework_name)
    if source == 'local'
      raise "VolvoxGrid: Local framework missing at #{destination}. Build/copy the XCFramework there, or use VOLVOXGRID_SOURCE=maven for published GitHub release assets." unless File.directory?(destination)
      FileUtils.rm_f("#{destination}.source")
      return
    end
    url = "https://github.com/ivere27/volvoxgrid/releases/download/v#{version}/#{framework_name}.zip"
    marker = "#{destination}.source"
    return if File.directory?(destination) && File.file?(marker) && File.read(marker) == url
    Dir.mktmpdir('volvoxgrid-native') do |tmp|
      archive = File.join(tmp, 'framework.zip')
      download(url, archive)
      raise "VolvoxGrid: Cannot unpack #{url}." unless system('unzip', '-o', archive, '-d', tmp)
      raise "VolvoxGrid: #{url} does not contain #{framework_name}." unless File.directory?(File.join(tmp, framework_name))
      FileUtils.mkdir_p(directory)
      FileUtils.rm_rf(destination)
      FileUtils.mv(File.join(tmp, framework_name), destination)
      File.write(marker, url)
    end
  end
end
