import Foundation
import XCTest
@testable import MdreviewApp

final class RendererLinkNavigationTests: XCTestCase {
    func testExternalWebLinksOpenOutsideTheRenderer() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/docs"))

        XCTAssertEqual(RendererLinkNavigationPolicy.action(for: url), .openExternally(url))
    }

    func testMailLinksOpenOutsideTheRenderer() throws {
        let url = try XCTUnwrap(URL(string: "mailto:hello@example.com"))

        XCTAssertEqual(RendererLinkNavigationPolicy.action(for: url), .openExternally(url))
    }

    func testRendererAnchorsStayInsideTheRenderer() throws {
        let url = try XCTUnwrap(URL(string: "file:///Applications/mdreview.app/Contents/Resources/renderer/index.html#usage"))

        XCTAssertEqual(RendererLinkNavigationPolicy.action(for: url), .allow)
    }

    func testResourceAndFileNavigationsStayInsideTheRenderer() throws {
        let resource = try XCTUnwrap(URL(string: "mdreview-resource://./images/logo.png"))
        let file = try XCTUnwrap(URL(string: "file:///Applications/mdreview.app/Contents/Resources/renderer/index.html"))

        XCTAssertEqual(RendererLinkNavigationPolicy.action(for: resource), .allow)
        XCTAssertEqual(RendererLinkNavigationPolicy.action(for: file), .allow)
    }
}
