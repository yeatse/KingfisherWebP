Pod::Spec.new do |s|
  s.name             = 'KingfisherWebP'
  s.version          = '0.3.1'
  s.summary          = 'A Kingfisher extension helping you process webp format'

  s.description      = <<-DESC
KingfisherWebP is an extension of the popular library [Kingfisher](https://github.com/onevcat/Kingfisher), providing a ImageProcessor and CacheSerializer for you to conveniently handle the WebP format.
                       DESC

  s.homepage         = 'https://github.com/yeatse/KingfisherWebP'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Yang Chao' => 'iyeatse@gmail.com' }
  s.source           = { :git => 'https://github.com/yeatse/KingfisherWebP.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/yeatse'

  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = "9.0"
#s.osx.deployment_target = "10.10" # Not supported for now
  s.watchos.deployment_target = "2.0"

  s.source_files = 'KingfisherWebP/Classes/**/*'
  s.public_header_files = 'KingfisherWebP/Classes/KingfisherWebP-umbrella.h'
  s.private_header_files = 'KingfisherWebP/Classes/CGImage+WebP.h'
  s.module_map = 'KingfisherWebP/KingfisherWebP.modulemap'

  s.xcconfig = {
    'USER_HEADER_SEARCH_PATHS' => '$(inherited) $(SRCROOT)/libwebp/src'
  }
  s.tvos.xcconfig = {
    'USER_HEADER_SEARCH_PATHS' => '$(inherited) $(SRCROOT)/libwebp/src'
  }
  s.osx.xcconfig = {
    'USER_HEADER_SEARCH_PATHS' => '$(inherited) $(SRCROOT)/libwebp/src'
  }
  s.watchos.xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) WEBP_USE_INTRINSICS=1',
    'USER_HEADER_SEARCH_PATHS' => '$(inherited) $(SRCROOT)/libwebp/src'
  }

  #s.osx.exclude_files = # None
  #s.watchos.exclude_files = # None
  #s.ios.exclude_files = # None
  #s.tvos.exclude_files = # None

  s.dependency 'Kingfisher', '4.2.0'
  s.dependency 'libwebp'
  
end
