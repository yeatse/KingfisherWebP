import UIKit
import XCTest
import Kingfisher
@testable import KingfisherWebP

class KingfisherWebPTests: XCTestCase {

    let fileNames = ["cover", "kingfisher", "logo"]
    let originalFileNames = ["cover.png", "kingfisher.jpg", "logo.png"]

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testWebPDecoding() {
        let p = WebPProcessor.default
        XCTAssertEqual(p.identifier, "com.yeatse.WebPProcessor")

        fileNames.enumerated().forEach { (index, fileName) in
            let data = Data(fileName: fileName, extension: "webp")
            let decodedImage = p.process(item: .data(data), options: [])
            XCTAssertNotNil(decodedImage, fileName)

            let originalData = Data(fileName: originalFileNames[index])
            let originalImage = Image(data: originalData)!

            XCTAssertTrue(decodedImage!.renderEqual(to: originalImage), fileName)
        }
    }

    func testDefaultDecoding() {
        let p = WebPProcessor.default
        XCTAssertEqual(p.identifier, "com.yeatse.WebPProcessor")

        originalFileNames.forEach { (fileName) in
            let data = Data(fileName: fileName)
            let image1 = p.process(item: .data(data), options: [])!
            let image2 = Image(data: data)!

            XCTAssertTrue(image1.renderEqual(to: image2), fileName)
        }
    }

    func testWebPSerializing() {
        let s = WebPSerializer.default

        originalFileNames.forEach { (fileName) in
            let image = Image(data: Data(fileName: fileName))!

            let serializedData = s.data(with: image, original: nil)
            XCTAssertNotNil(serializedData, fileName)

            let encodedImage = s.image(with: serializedData!, options: [])
            XCTAssertNotNil(encodedImage, fileName)

            XCTAssertTrue(image.renderEqual(to: encodedImage!), fileName)
        }
    }

    func testDefaultSerializing() {
        let s = WebPSerializer.default

        originalFileNames.forEach { (fileName) in
            let data = Data(fileName: fileName)
            let image = Image(data: data)!

            let defaultSerializedData = DefaultCacheSerializer.default.data(with: image, original: data)
            let serializedData = s.data(with: image, original: data)

            XCTAssertEqual(defaultSerializedData, serializedData, fileName)
        }
    }

    func testEncodingPerformance() {
        let s = WebPSerializer.default
        let images = originalFileNames.map({ Image(data: Data(fileName: $0))! })
        measure {
            images.forEach({ (image) in
                let _ = s.data(with: image, original: nil)
            })
        }
    }

    func testDecodingperformance() {
        let p = WebPProcessor.default
        let dataList = fileNames.map({ Data(fileName: $0, extension: "webp") })
        measure {
            dataList.forEach({ (data) in
                let _ = p.process(item: .data(data), options: [])
            })
        }
    }
}

// MARK: - Helper
extension Data {
    init(fileName: String, extension: String? = nil) {
        let url = Bundle(for: KingfisherWebPTests.self).url(forResource: fileName, withExtension: `extension`)!
        try! self.init(contentsOf: url)
    }
}

// Copied from Kingfisher project
extension Image {
    func renderEqual(to image: Image, withinTolerance tolerance: UInt8 = 3, tolerancePercent: Double = 0) -> Bool {

        guard size == image.size else { return false }
        guard let imageData1 = UIImagePNGRepresentation(self), let imageData2 = UIImagePNGRepresentation(image) else { return false }
        guard let unifiedImage1 = Image(data: imageData1), let unifiedImage2 = Image(data: imageData2) else { return false }

        guard let rendered1 = unifiedImage1.rendered(), let rendered2 = unifiedImage2.rendered() else { return false }
        guard let data1 = rendered1.cgImage?.dataProvider?.data, let data2 = rendered2.cgImage?.dataProvider?.data else { return false }

        let length1 = CFDataGetLength(data1)
        let length2 = CFDataGetLength(data2)
        guard length1 == length2 else { return false }

        let dataPtr1: UnsafePointer<UInt8> = CFDataGetBytePtr(data1)
        let dataPtr2: UnsafePointer<UInt8> = CFDataGetBytePtr(data2)


        var dismatchedLength = 0;

        for index in 0..<length1 {
            let byte1 = dataPtr1[index]
            let byte2 = dataPtr2[index]
            let delta = UInt8(abs(Int(byte1) - Int(byte2)))

            if delta > tolerance {
                dismatchedLength += 1
            }
        }

        return dismatchedLength <= Int(tolerancePercent * Double(length1))
    }

    func rendered() -> Image? {
        // Ignore non CG images
        guard let cgImage = cgImage else {
            return nil
        }

        var bitmapInfo = cgImage.bitmapInfo
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let alpha = (bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue)

        let w = cgImage.width
        let h = cgImage.height

        let size = CGSize(width: w, height: h)

        if alpha == CGImageAlphaInfo.none.rawValue {
            bitmapInfo.remove(.alphaInfoMask)
            bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
        } else if !(alpha == CGImageAlphaInfo.noneSkipFirst.rawValue) || !(alpha == CGImageAlphaInfo.noneSkipLast.rawValue) {
            bitmapInfo.remove(.alphaInfoMask)
            bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        }

        // Render the image
        guard let context = CGContext(data: nil,
                                      width: w,
                                      height: h,
                                      bitsPerComponent: cgImage.bitsPerComponent,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else
        {
            return nil
        }

        context.draw(cgImage, in: CGRect(origin: CGPoint.zero, size: size))

        #if os(macOS)
            return context.makeImage().flatMap { Image(cgImage: $0, size: kf.size) }
        #else
            return context.makeImage().flatMap { Image(cgImage: $0) }
        #endif
    }
}
