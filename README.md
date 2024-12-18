# KingfisherWebP

[![CI Status](https://github.com/Yeatse/KingfisherWebP/workflows/unittest/badge.svg)](https://travis-ci.org/Yeatse/KingfisherWebP)
[![Version](https://img.shields.io/cocoapods/v/KingfisherWebP.svg?style=flat)](http://cocoapods.org/pods/KingfisherWebP)
[![License](https://img.shields.io/cocoapods/l/KingfisherWebP.svg?style=flat)](http://cocoapods.org/pods/KingfisherWebP)
[![Platform](https://img.shields.io/cocoapods/p/KingfisherWebP.svg?style=flat)](http://cocoapods.org/pods/KingfisherWebP)

# Description

KingfisherWebP is an extension of the popular library [Kingfisher](https://github.com/onevcat/Kingfisher), providing an ImageProcessor and CacheSerializer for you to conveniently handle the [WebP format](https://developers.google.com/speed/webp/). Animated WebP is also supported!

The library works seamlessly with `Kingfisher`. To display the webp images from network, simply add `WebPProcessor` and `WebPSerializer` to your `KingfisherOptionsInfo`:

```swift
let url = URL(string: "url_of_your_webp_image")
imageView.kf.setImage(with: url, options: [.processor(WebPProcessor.default), .cacheSerializer(WebPSerializer.default)])
```

For convenience, you may set it as a global default option to all `KingfisherManager` related methods:

```swift
// somewhere after your application launches...

KingfisherManager.shared.defaultOptions += [
  .processor(WebPProcessor.default),
  .cacheSerializer(WebPSerializer.default)
]

// You can now use webp in Kingfisher like any other format
imageView.kf.setImage(with: url)
```

Some image servers may expect the `"Accept"` header to include `"image/webp"`.
You can include this header to all Kingfisher requests by doing:
```swift
let modifier = AnyModifier { request in
    var req = request
    req.addValue("image/webp */*", forHTTPHeaderField: "Accept")
    return req
}

KingfisherManager.shared.defaultOptions += [
    .requestModifier(modifier),
    // ... other options
]
```

If the image data is not in webp format, the default processor and serializer in `Kingfisher` will be used.


## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

iOS 12 or above

## Installation

### CocoaPods

KingfisherWebP is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod "KingfisherWebP"
```

### Swift Package Manager

From Xcode 11, you can use [Swift Package Manager](https://swift.org/package-manager/) to add KingfisherWebP to your project. The "package repository url" of KingfisherWebP is `https://github.com/yeatse/KingfisherWebP.git`.

![SPM screenshot](spm_screenshot.png)

### Carthage

You can also add KingfisherWebP using [Carthage](https://github.com/Carthage/Carthage). Note that KingfisherWebP is built on top of [libwebp](https://chromium.googlesource.com/webm/libwebp) project, so in your `Cartfile` you should add `libwebp` dependency as well:

```
github "yeatse/KingfisherWebP" ~> 1.4.0
github "onevcat/Kingfisher" ~> 7.0.0
github "SDWebImage/libwebp-Xcode" ~> 1.1.0
```


## Author

Yang Chao, iyeatse@gmail.com

## License

KingfisherWebP is available under the MIT license. See the LICENSE file for more info.
