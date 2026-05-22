import Foundation
import XCTest
@testable import MdreviewCore

final class AppReducerTests: XCTestCase {
    func testOpeningSameFileFocusesExistingTab() throws {
        let file = URL(fileURLWithPath: "/tmp/README.md")
        var model = AppModel()
        let first = AppReducer.apply(.openFile(file, newWindow: false), to: &model)
        let second = AppReducer.apply(.openFile(file, newWindow: false), to: &model)

        XCTAssertEqual(first, .opened)
        XCTAssertEqual(second, .focused)
        XCTAssertEqual(model.windows.count, 1)
        XCTAssertEqual(model.windows[0].tabs.count, 1)
    }

    func testDirectoryOpenReplacesWorkspaceAndClosesOldTabs() throws {
        var model = AppModel()
        _ = AppReducer.apply(.openFile(URL(fileURLWithPath: "/tmp/old.md"), newWindow: false), to: &model)
        _ = AppReducer.apply(.openDirectory(URL(fileURLWithPath: "/tmp/docs"), defaultDocument: URL(fileURLWithPath: "/tmp/docs/README.md"), fileTree: [], newWindow: false), to: &model)

        XCTAssertEqual(model.windows.count, 1)
        XCTAssertEqual(model.windows[0].workspaceRoot?.path, "/tmp/docs")
        XCTAssertEqual(model.windows[0].tabs.map(\.url.path), ["/tmp/docs/README.md"])
    }

    func testNewWindowDirectoryCreatesSecondWindow() throws {
        var model = AppModel()
        _ = AppReducer.apply(.openDirectory(URL(fileURLWithPath: "/tmp/a"), defaultDocument: URL(fileURLWithPath: "/tmp/a/README.md"), fileTree: [], newWindow: false), to: &model)
        _ = AppReducer.apply(.openDirectory(URL(fileURLWithPath: "/tmp/b"), defaultDocument: URL(fileURLWithPath: "/tmp/b/README.md"), fileTree: [], newWindow: true), to: &model)

        XCTAssertEqual(model.windows.count, 2)
        XCTAssertEqual(model.windows[1].workspaceRoot?.path, "/tmp/b")
    }

    func testSingleFileWithoutWorkspaceUsesOutlineOnlyLayout() {
        var model = AppModel()
        _ = AppReducer.apply(.openFile(URL(fileURLWithPath: "/tmp/README.md"), newWindow: false), to: &model)
        XCTAssertEqual(model.windows[0].layoutMode, .outlineAndDocument)
    }
}
