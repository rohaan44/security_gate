#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint security_gate.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'security_gate'
  s.version          = '0.1.0'
  s.summary          = 'A pluggable device-security-check pipeline for Flutter.'
  s.description      = <<-DESC
A pluggable device-security-check pipeline for Flutter.
                       DESC
  s.homepage         = 'https://github.com/example/security_gate'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
