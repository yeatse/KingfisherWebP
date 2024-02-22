//
//  WebPSerializer.swift
//  Pods
//
//  Created by yeatse on 2016/10/20.
//
//

import CoreGraphics
import Foundation
import Kingfisher

public struct WebPSerializer: CacheSerializer {
    public static let `default` = WebPSerializer()
    
    /// Whether the image should be serialized in a lossy format. Default is false.
    public var isLossy: Bool = false
    
    /// The compression quality when converting image to a lossy format data. Default is 1.0.
    public var compressionQuality: CGFloat = 1.0
    
    /// See ```CacheSerializer/originalDataUsed```
    public var originalDataUsed: Bool = true
    
    private init() {}

    public func data(with image: KFCrossPlatformImage, original: Data?) -> Data? {
        if originalDataUsed {
            if let original = original {
                return original
            }
            if let frameData = image.kf.frameSource?.data {
                return frameData
            }
        }
        if let original = original, !original.isWebPFormat {
            return DefaultCacheSerializer.default.data(with: image, original: original)
        }
        let qualityInWebp = min(max(0, compressionQuality), 1) * 100
        return image.kf.normalized.kf.webpRepresentation(isLossy: isLossy, quality: Float(qualityInWebp))
    }

    public func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        return WebPProcessor.default.process(item: .data(data), options: options)
    }
}
