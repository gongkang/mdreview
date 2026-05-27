import WebKit
import XCTest
@testable import MdreviewApp

@MainActor
final class RendererZoomTests: XCTestCase {
    func testRendererAllowsTrackpadMagnification() throws {
        let controller = RendererViewController(resourceHandler: ResourceSchemeHandler())
        controller.loadViewIfNeeded()

        let webView = try XCTUnwrap(controller.view as? WKWebView)
        XCTAssertTrue(webView.allowsMagnification)
    }
}
