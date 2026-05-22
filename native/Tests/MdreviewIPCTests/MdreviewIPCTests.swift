import XCTest
@testable import MdreviewIPC

final class MdreviewIPCTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertNotNil(MdreviewIPCModule.self)
    }
}
