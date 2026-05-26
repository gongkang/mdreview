import Foundation
import XCTest
@testable import MdreviewCore

final class ResourceSchemeTests: XCTestCase {
    func testParsesMdreviewResourceURL() throws {
        let parsed = try ResourceURL.parse(URL(string: "mdreview-resource://./images/logo.png")!)
        XCTAssertEqual(parsed, "./images/logo.png")
    }

    func testParsesAbsoluteMdreviewResourceURL() throws {
        let parsed = try ResourceURL.parse(URL(string: "mdreview-resource:///Users/me/images/logo%20wide.png")!)
        XCTAssertEqual(parsed, "/Users/me/images/logo wide.png")
    }
}
