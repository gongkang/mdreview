import Darwin
import XCTest
@testable import MdreviewCore

final class OpenRequestTests: XCTestCase {
    func testDecodesOpenFileRequest() throws {
        let json = #"{"kind":"openFile","path":"/tmp/README.md","newWindow":false}"#.data(using: .utf8)!
        let request = try JSONDecoder().decode(OpenRequest.self, from: json)
        XCTAssertEqual(request.kind, .openFile)
        XCTAssertEqual(request.path, "/tmp/README.md")
        XCTAssertEqual(request.newWindow, false)
    }

    func testEncodesAcceptedResponse() throws {
        let response = OpenResponse(accepted: true, action: .opened, message: "已打开")
        let data = try JSONEncoder().encode(response)
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains(#""accepted":true"#))
        XCTAssertTrue(text.contains(#""action":"opened""#))
    }

    func testSocketPathUsesCurrentUserTmpDirectory() {
        let path = SocketLocation.defaultPath()
        XCTAssertTrue(path.hasSuffix("mdreview-\(getuid()).sock"))
        XCTAssertTrue(path.contains("/"))
    }
}
