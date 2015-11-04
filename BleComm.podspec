#
# Be sure to run `pod lib lint BleComm.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "BleComm"
  s.version          = "0.3.0"
  s.summary          = "Simple BLE Communction Library"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
A Simple iOS BLE Communication Library as CocoaPod
                       DESC

  s.homepage         = "https://github.com/perusworld/BleComm"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Saravana Perumal Shanmugam" => "saravanaperumal@msn.com" }
  s.source           = { :git => "https://github.com/perusworld/BleComm.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/perusworld'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'BleComm' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
