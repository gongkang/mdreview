import AppKit
import XCTest
@testable import MdreviewApp
@testable import MdreviewCore

@MainActor
final class MainWindowLayoutTests: XCTestCase {
    func testSplitViewFillsDocumentAreaAndUsesSideBySideColumns() {
        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: URL(fileURLWithPath: "/tmp/README.md"))
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = findSubview(ofType: NSSplitView.self, in: controller.window?.contentView)
        XCTAssertNotNil(splitView)
        XCTAssertEqual(splitView?.isVertical, true)
        XCTAssertGreaterThan(splitView?.frame.height ?? 0, 650)
        XCTAssertGreaterThan(splitView?.subviews.last?.frame.width ?? 0, 700)
    }

    func testSingleFileShowsNativeOutlineHeadings() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-outline-\(UUID().uuidString).md")
        try "# Title\n\n## Usage\n".write(to: file, atomically: true, encoding: .utf8)
        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: file)
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let buttonTitles = findSubviews(ofType: NSButton.self, in: controller.window?.contentView).map(\.title)
        XCTAssertTrue(buttonTitles.contains("Title"))
        XCTAssertTrue(buttonTitles.contains("  Usage"))

        let titleButton = findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first { $0.title == "Title" }
        XCTAssertGreaterThan(titleButton?.frame.width ?? 0, 40)
        XCTAssertGreaterThan(titleButton?.frame.height ?? 0, 16)
        XCTAssertEqual(titleButton?.superview?.isFlipped, true)
    }

    private func findSubview<T: NSView>(ofType type: T.Type, in view: NSView?) -> T? {
        guard let view else { return nil }
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let match = findSubview(ofType: type, in: subview) {
                return match
            }
        }
        return nil
    }

    private func findSubviews<T: NSView>(ofType type: T.Type, in view: NSView?) -> [T] {
        guard let view else { return [] }
        var matches = [T]()
        if let match = view as? T {
            matches.append(match)
        }
        for subview in view.subviews {
            matches.append(contentsOf: findSubviews(ofType: type, in: subview))
        }
        return matches
    }
}
