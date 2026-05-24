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
}
