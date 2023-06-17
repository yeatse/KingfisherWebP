//
//  Image+WebP.swift
//  Pods
//
//  Created by yeatse on 2016/10/19.
//
//

import Kingfisher
import CoreGraphics
import Foundation

#if SWIFT_PACKAGE
import KingfisherWebP_ObjC
#endif

// MARK: - Image Representation
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    /// isLossy  (0=lossy , 1=lossless (default)).
    /// Note that the default values are isLossy= false and quality=75.0f
    public func webpRepresentation(isLossy: Bool = false, quality: Float = 75.0) -> Data? {
        if let result = animatedWebPRepresentation(isLossy: isLossy, quality: quality) {
            return result
        }
        #if os(macOS)
        if let cgImage = base.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return WebPDataCreateWithImage(cgImage, isLossy, quality) as Data?
        }
        #else
        if let cgImage = base.cgImage {
            return WebPDataCreateWithImage(cgImage, isLossy, quality) as Data?
        }
        #endif
        return nil
    }

    /// isLossy  (0=lossy , 1=lossless (default)).
    /// Note that the default values are isLossy= false and quality=75.0f
    private func animatedWebPRepresentation(isLossy: Bool = false, quality: Float = 75.0) -> Data? {
        #if os(macOS)
        return nil
        #else
        guard let images = base.images?.compactMap({ $0.cgImage }) else {
            return nil
        }
        let imageInfo = [ kWebPAnimatedImageFrames: images,
                          kWebPAnimatedImageDuration: NSNumber(value: base.duration) ] as [CFString : Any]
        return WebPDataCreateWithAnimatedImageInfo(imageInfo as CFDictionary, isLossy, quality) as Data?
        #endif
    }
}

// MARK: - Create image from WebP data
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    public static func image(webpData: Data, scale: CGFloat, onlyFirstFrame: Bool) -> KFCrossPlatformImage? {
        let options = ImageCreatingOptions(scale: scale, preloadAll: true, onlyFirstFrame: onlyFirstFrame)
        return image(webpData: webpData, options: options)
    }
    
    public static func image(webpData: Data, options: ImageCreatingOptions) -> KFCrossPlatformImage? {
        let frameCount = WebPImageFrameCountGetFromData(webpData as CFData)
        if (frameCount == 0) {
            return nil
        }
        
        if (frameCount == 1 || options.onlyFirstFrame) {
            // MARK: Still image
            guard let cgImage = WebPImageCreateWithData(webpData as CFData) else {
                return nil
            }
            #if os(macOS)
            let image = KFCrossPlatformImage(cgImage: cgImage, size: .zero)
            #else
            let image = KFCrossPlatformImage(cgImage: cgImage, scale: options.scale, orientation: .up)
            #endif
            image.kf.imageFrameCount = Int(frameCount)
            return image
        }

        // MARK: Animated images
        guard let frameSource = WebPFrameSource(data: webpData) else { return nil }
        return KingfisherWrapper.animatedImage(source: frameSource, options: options)
    }
}

class WebPFrameSource: ImageFrameSource {
    init?(data: Data) {
        guard let decoder = WebPDecoderCreateWithData(data as CFData) else {
            return nil
        }
        // We intentionally set data to nil to prevent Kingfisher from decoding this data a second time.
        // https://github.com/onevcat/Kingfisher/blob/3f6992b5cd3143e83b02300ea59c400d4cf0747a/Sources/General/KingfisherManager.swift#L562
        self.data = nil
        self.decoder = decoder
    }
    
    deinit {
        WebPDecoderDestroy(decoder)
    }
    
    let data: Data?
    private let decoder: WebPDecoderRef
    
    var frameCount: Int {
        get {
            return Int(WebPDecoderGetFrameCount(decoder))
        }
    }
    
    func frame(at index: Int, maxSize: CGSize?) -> CGImage? {
        guard let image = WebPDecoderCopyImageAtIndex(decoder, Int32(index)) else {
            return nil
        }
        if let maxSize = maxSize, maxSize != .zero, CGFloat(image.width) > maxSize.width || CGFloat(image.height) > maxSize.height {
            let scale = max(maxSize.width / CGFloat(image.width), maxSize.height / CGFloat(image.height))
            let destWidth = Int(CGFloat(image.width) * scale)
            let destHeight = Int(CGFloat(image.height) * scale)
            let context = CGContext(data: nil,
                                    width: destWidth,
                                    height: destHeight,
                                    bitsPerComponent: image.bitsPerComponent,
                                    bytesPerRow: 0,
                                    space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: image.bitmapInfo.rawValue)
            context?.interpolationQuality = .high
            context?.draw(image, in: CGRect(x: 0, y: 0, width: destWidth, height: destHeight))
            return context?.makeImage() ?? image
        }
        return image
    }
    
    func duration(at index: Int) -> TimeInterval {
        return TimeInterval(WebPDecoderGetDurationAtIndex(decoder, Int32(index)))
    }
}

// MARK: - WebP Format Testing
extension Data {
    public var isWebPFormat: Bool {
        if count < 12 {
            return false
        }

        let endIndex = index(startIndex, offsetBy: 12)
        let testData = subdata(in: startIndex..<endIndex)
        guard let testString = String(data: testData, encoding: .ascii) else {
            return false
        }

        if testString.hasPrefix("RIFF") && testString.hasSuffix("WEBP") {
            return true
        } else {
            return false
        }
    }
}
