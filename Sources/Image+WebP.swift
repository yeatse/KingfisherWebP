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
import Accelerate

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
        if let maxSize = maxSize, maxSize != .zero, (CGFloat(image.width) > maxSize.width || CGFloat(image.height) > maxSize.height) {
            // Scale down image to fit maxSize while preserving aspect ratio
            // Try vImage first for better performance, fallback to CGContext if fails
            if let scaledImage = scaleImageUsingVImage(image, maxSize: maxSize) ?? scaleImageUsingContext(image, maxSize: maxSize) {
                return scaledImage
            }
        }
        return image
    }

    private func calculateTargetSize(sourceWidth: Int, sourceHeight: Int, maxSize: CGSize) -> (width: Int, height: Int)? {
        // Calculate target size preserving aspect ratio
        let widthRatio = maxSize.width / CGFloat(sourceWidth)
        let heightRatio = maxSize.height / CGFloat(sourceHeight)
        let scale = min(widthRatio, heightRatio)

        let targetWidth = Int(CGFloat(sourceWidth) * scale)
        let targetHeight = Int(CGFloat(sourceHeight) * scale)

        guard targetWidth > 0, targetHeight > 0 else { return nil }
        return (targetWidth, targetHeight)
    }

    private func scaleImageUsingVImage(_ image: CGImage, maxSize: CGSize) -> CGImage? {
        let sourceWidth = image.width
        let sourceHeight = image.height

        guard let targetSize = calculateTargetSize(sourceWidth: sourceWidth, sourceHeight: sourceHeight, maxSize: maxSize) else {
            return nil
        }
        let (targetWidth, targetHeight) = targetSize

        // Get source image properties
        guard let colorSpace = image.colorSpace else { return nil }
        let bitmapInfo = image.bitmapInfo
        let bitsPerComponent = image.bitsPerComponent
        let bytesPerPixel = image.bitsPerPixel / 8

        // Create source buffer
        guard let sourceData = image.dataProvider?.data,
              let sourceBytes = CFDataGetBytePtr(sourceData) else {
            return nil
        }

        var sourceBuffer = vImage_Buffer(
            data: UnsafeMutableRawPointer(mutating: sourceBytes),
            height: vImagePixelCount(sourceHeight),
            width: vImagePixelCount(sourceWidth),
            rowBytes: image.bytesPerRow
        )

        // Create destination buffer
        let destBytesPerRow = targetWidth * bytesPerPixel
        let destDataSize = targetHeight * destBytesPerRow
        guard let destData = CFDataCreateMutable(kCFAllocatorDefault, destDataSize) else {
            return nil
        }
        CFDataSetLength(destData, destDataSize)

        guard let destBytes = CFDataGetMutableBytePtr(destData) else {
            return nil
        }
        var destBuffer = vImage_Buffer(
            data: destBytes,
            height: vImagePixelCount(targetHeight),
            width: vImagePixelCount(targetWidth),
            rowBytes: destBytesPerRow
        )

        // Perform scaling
        let error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageHighQualityResampling))

        guard error == kvImageNoError else {
            return nil
        }

        // Create CGImage from destination buffer
        guard let dataProvider = CGDataProvider(data: destData) else {
            return nil
        }

        let scaledImage = CGImage(
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: image.bitsPerPixel,
            bytesPerRow: destBytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )

        return scaledImage
    }

    private func scaleImageUsingContext(_ image: CGImage, maxSize: CGSize) -> CGImage? {
        let sourceWidth = image.width
        let sourceHeight = image.height

        guard let targetSize = calculateTargetSize(sourceWidth: sourceWidth, sourceHeight: sourceHeight, maxSize: maxSize) else {
            return nil
        }
        let (targetWidth, targetHeight) = targetSize

        // Get image properties
        guard let colorSpace = image.colorSpace else { return nil }
        let bitmapInfo = image.bitmapInfo

        // Create context and draw scaled image
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        return context.makeImage()
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

        let riffHeader = subdata(in: startIndex..<index(startIndex, offsetBy: 4))
        let webpHeader = subdata(in: index(startIndex, offsetBy: 8)..<index(startIndex, offsetBy: 12))

        let riffString = String(data: riffHeader, encoding: .ascii)
        let webpString = String(data: webpHeader, encoding: .ascii)

        return riffString == "RIFF" && webpString == "WEBP"
    }
}
