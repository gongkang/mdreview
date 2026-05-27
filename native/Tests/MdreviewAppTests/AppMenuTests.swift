import AppKit
import XCTest
@testable import MdreviewApp
@testable import MdreviewCore

@MainActor
final class AppMenuTests: XCTestCase {
    func testAppMenuContainsSettingsSeparatorAndQuit() throws {
        let delegate = AppDelegate()
        let menu = delegate.buildMenu()
        let appMenu = try XCTUnwrap(menu.item(at: 0)?.submenu)

        XCTAssertEqual(appMenu.item(at: 0)?.title, MenuText.settings)
        XCTAssertTrue(appMenu.item(at: 1)?.isSeparatorItem ?? false)

        let quit = try XCTUnwrap(appMenu.item(at: 2))
        XCTAssertEqual(quit.title, MenuText.quit)
        XCTAssertEqual(quit.keyEquivalent, "q")
        XCTAssertEqual(quit.action, #selector(NSApplication.terminate(_:)))
        XCTAssertTrue(try XCTUnwrap(quit.target as AnyObject?) === NSApplication.shared)
    }

    func testViewMenuUsesSidebarToggleActions() throws {
        let delegate = AppDelegate()
        let menu = delegate.buildMenu()
        let viewMenu = try XCTUnwrap(menu.items.compactMap(\.submenu).first { $0.title == MenuText.view })

        let filesItem = try XCTUnwrap(viewMenu.item(withTitle: MenuText.toggleFiles))
        let outlineItem = try XCTUnwrap(viewMenu.item(withTitle: MenuText.toggleOutline))

        XCTAssertEqual(NSStringFromSelector(try XCTUnwrap(filesItem.action)), "toggleFiles")
        XCTAssertEqual(NSStringFromSelector(try XCTUnwrap(outlineItem.action)), "toggleOutline")
        XCTAssertTrue(try XCTUnwrap(filesItem.target as AnyObject?) === delegate)
        XCTAssertTrue(try XCTUnwrap(outlineItem.target as AnyObject?) === delegate)
    }

    func testViewMenuContainsPreviewZoomActions() throws {
        let delegate = AppDelegate()
        let menu = delegate.buildMenu()
        let viewMenu = try XCTUnwrap(menu.items.compactMap(\.submenu).first { $0.title == MenuText.view })

        let zoomInItem = try XCTUnwrap(viewMenu.item(withTitle: MenuText.zoomInPreview))
        let zoomOutItem = try XCTUnwrap(viewMenu.item(withTitle: MenuText.zoomOutPreview))
        let resetZoomItem = try XCTUnwrap(viewMenu.item(withTitle: MenuText.resetPreviewZoom))

        XCTAssertEqual(NSStringFromSelector(try XCTUnwrap(zoomInItem.action)), "zoomInPreview")
        XCTAssertEqual(NSStringFromSelector(try XCTUnwrap(zoomOutItem.action)), "zoomOutPreview")
        XCTAssertEqual(NSStringFromSelector(try XCTUnwrap(resetZoomItem.action)), "resetPreviewZoom")
        XCTAssertEqual(zoomInItem.keyEquivalent, "+")
        XCTAssertEqual(zoomOutItem.keyEquivalent, "-")
        XCTAssertEqual(resetZoomItem.keyEquivalent, "0")
        XCTAssertTrue(try XCTUnwrap(zoomInItem.target as AnyObject?) === delegate)
        XCTAssertTrue(try XCTUnwrap(zoomOutItem.target as AnyObject?) === delegate)
        XCTAssertTrue(try XCTUnwrap(resetZoomItem.target as AnyObject?) === delegate)
    }
}
