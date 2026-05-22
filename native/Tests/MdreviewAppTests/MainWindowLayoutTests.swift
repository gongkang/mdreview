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
}
