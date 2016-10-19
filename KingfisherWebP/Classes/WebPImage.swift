//
//  WebPImage.swift
//  Pods
//
//  Created by yeatse on 2016/10/19.
//
//

import Kingfisher

// MARK: - Image Representation
extension Kingfisher where Base: Image {
    // MARK: - WebP
    func webpRepresentation() -> Data? {
        return UIImagePNGRepresentation(base)
    }
}

// MARK: - Create image from WebP data
extension Kingfisher where Base: Image {
    static func image(webpData: Data, scale: CGFloat) -> Image? {
        return UIImage.sd_image(withWebPData: webpData)
    }
}

extension Data {
    var isWebPFormat: Bool {
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
