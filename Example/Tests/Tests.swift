import UIKit
import XCTest
import KingfisherWebP
import Kingfisher

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testProcessor() {
        let p = WebPImageProcessor.default
        XCTAssertEqual(p.identifier, "com.yeatse.KingfisherWebP.Processor")
        let url = Bundle(for: Tests.self).url(forResource: "cover", withExtension: "webp")
        let data = try! Data(contentsOf: url!)
        let resultImage = p.process(item: .data(data), options: [])
        XCTAssertNotNil(resultImage)
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
