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

#if canImport(AppKit)
import AppKit
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
        let imageInfo: [CFString: Any]
        if let frameSource = frameSource {
            let frameCount = frameSource.frameCount
            imageInfo = [
                kWebPAnimatedImageFrames: (0..<frameCount).map({ frameSource.frame(at: $0) }),
                kWebPAnimatedImageFrameDurations: (0..<frameCount).map({ frameSource.duration(at: $0) }),
            ]
        } else {
#if os(macOS)
            return nil
#else
            guard let images = base.images?.compactMap({ $0.cgImage }) else {
                return nil
            }
            imageInfo = [
                kWebPAnimatedImageFrames: images,
                kWebPAnimatedImageDuration: base.duration
            ]
#endif
        }
        return WebPDataCreateWithAnimatedImageInfo(imageInfo as CFDictionary, isLossy, quality) as Data?
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
        self.data = data
        self.decoder = decoder
        // http://www.russbishop.net/the-law
        self.decoderLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.decoderLock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        WebPDecoderDestroy(decoder)
        decoderLock.deallocate()
    }
    
    let data: Data?
    private let decoder: WebPDecoderRef
    private var decoderLock: UnsafeMutablePointer<os_unfair_lock>
    private var frameCache = NSCache<NSNumber, CGImage>()
    
    var frameCount: Int {
        get {
            return Int(WebPDecoderGetFrameCount(decoder))
        }
    }
    
    func frame(at index: Int, maxSize: CGSize?) -> CGImage? {
        os_unfair_lock_lock(decoderLock)
        defer {
            os_unfair_lock_unlock(decoderLock)
        }
        var image = frameCache.object(forKey: index as NSNumber)
        if image == nil {
            image = WebPDecoderCopyImageAtIndex(decoder, Int32(index))
            if image != nil {
                frameCache.setObject(image!, forKey: index as NSNumber)
            }
        }
        guard let image = image else { return nil }
        if let maxSize = maxSize, maxSize != .zero, CGFloat(image.width) > maxSize.width || CGFloat(image.height) > maxSize.height {
            let scale = min(maxSize.width / CGFloat(image.width), maxSize.height / CGFloat(image.height))
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
        let duration = WebPDecoderGetDurationAtIndex(decoder, Int32(index))
        // https://github.com/onevcat/Kingfisher/blob/3f6992b5cd3143e83b02300ea59c400d4cf0747a/Sources/Image/GIFAnimatedImage.swift#L106
        if duration > 0.011 {
            return duration
        } else {
            return 0.1
        }
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
