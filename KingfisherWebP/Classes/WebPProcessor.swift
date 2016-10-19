//
//  WebPProcessor.swift
//  Pods
//
//  Created by yeatse on 2016/10/19.
//
//

import Foundation
import Kingfisher

public struct WebPImageProcessor: ImageProcessor {
    public static let `default` = WebPImageProcessor()
    
    public let identifier = "com.yeatse.KingfisherWebP.Processor"
    
    public init() {}
    
    public func process(item: ImageProcessItem, options: KingfisherOptionsInfo) -> Image? {
        switch item {
        case .image(let image):
            return image
        case .data(let data):
            if data.isWebPFormat {
                return Kingfisher<Image>.image(webpData: data, scale: options.scaleFactor)
            } else {
                return DefaultImageProcessor.default.process(item: item, options: options)
            }
        }
    }
}

extension Collection where Iterator.Element == KingfisherOptionsInfoItem {
    var scaleFactor: CGFloat {
        let item = index {
            if case .scaleFactor = $0 { return true }
            else { return false }
            }.flatMap{ self[$0] }
        
        if let item = item, case .scaleFactor(let scale) = item {
            return scale
        } else {
            return 1.0
        }
    }
}
