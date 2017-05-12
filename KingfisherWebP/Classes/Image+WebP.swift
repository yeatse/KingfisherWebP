//
//  Image+WebP.swift
//  Pods
//
//  Created by yeatse on 2016/10/19.
//
//

import Kingfisher
import KingfisherWebP.Private

// MARK: - Image Representation
extension Kingfisher where Base: Image {
    func webpRepresentation() -> Data? {
        guard let cgImage = base.cgImage else {
            return nil
        }
        return WebPRepresentationDataCreateWithImage(cgImage) as Data?
    }
}

// MARK: - Create image from WebP data
extension Kingfisher where Base: Image {
    static func image(webpData: Data, scale: CGFloat) -> Image? {
        let useThreads = true; //speed up 23%
        let bypassFiltering = false; //speed up 11%, cause some banding
        let noFancyUpsampling = false; //speed down 16%, lose some details

        guard let cgImage = CGImageCreateWithWebPData(  webpData as CFData, useThreads, bypassFiltering, noFancyUpsampling) else {
            return nil;
        }

        return Image(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

// MARK: - WebP Format Testing
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

// MARK: - Helper
extension KingfisherOptionsInfoItem {
    var isScaleFactor: Bool {
        if case .scaleFactor = self {
            return true
        } else {
            return false
        }
    }
}

extension Collection where Iterator.Element == KingfisherOptionsInfoItem {
    var firstScaleFactorItem: KingfisherOptionsInfoItem? {
        return index { $0.isScaleFactor }.flatMap { self[$0] }
    }

    var scaleFactor: CGFloat {
        if let item = firstScaleFactorItem, case .scaleFactor(let scale) = item {
            return scale
        }
        return 1.0
    }
}
