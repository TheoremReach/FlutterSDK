require 'yaml'

pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))

Pod::Spec.new do |s|
  s.name             = 'theoremreach_sdk'
  s.version          = pubspec['version']
  s.summary          = "TheoremReach's rewarded surveys for Flutter apps."
  s.description      = pubspec['description']
  s.homepage         = pubspec['repository']
  s.license          = { :type => 'Commercial', :file => '../LICENSE' }
  s.author           = { 'TheoremReach' => 'admin@theoremreach.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'

  s.source_files = 'theoremreach_sdk/Sources/theoremreach_sdk/**/*.swift'
  s.dependency 'Flutter'

  # The TheoremReach iOS SDK, from TheoremReach/iOSSDK's release tag (CI checks it against the tag). Package.swift names
  # the same copy, for Swift Package Manager. The system frameworks are the ones it links.
  s.vendored_frameworks = 'theoremreach_sdk/Frameworks/TheoremReachSDK.xcframework'
  s.frameworks = 'AdSupport', 'CoreTelephony', 'JavaScriptCore', 'Security', 'SystemConfiguration', 'UIKit', 'WebKit'

  # Flutter.framework has no i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
