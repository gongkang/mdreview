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

        let rows = findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView)
        let titleRow = rows.first { $0.title == "Title" }
        let usageRow = rows.first { $0.title == "Usage" }

        XCTAssertNotNil(titleRow)
        XCTAssertNotNil(usageRow)
        XCTAssertEqual(titleRow?.depth, 0)
        XCTAssertEqual(usageRow?.depth, 1)
        XCTAssertGreaterThan(titleRow?.frame.width ?? 0, 40)
        XCTAssertGreaterThan(titleRow?.frame.height ?? 0, 16)
        XCTAssertEqual(titleRow?.superview?.isFlipped, true)
    }

    func testSingleFileOutlineUsesAccessibleTextNavigationRows() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-reader-outline-\(UUID().uuidString).md")
        try "# Title\n\n## Usage\n".write(to: file, atomically: true, encoding: .utf8)
        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: file)
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let rows = findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView)
        let titleRow = try XCTUnwrap(rows.first { $0.title == "Title" })
        let usageRow = try XCTUnwrap(rows.first { $0.title == "Usage" })

        XCTAssertFalse(titleRow.isBordered)
        XCTAssertEqual(titleRow.bezelStyle, .regularSquare)
        XCTAssertEqual(titleRow.alignment, .left)
        XCTAssertEqual(titleRow.accessibilityLabel(), "Title")
        XCTAssertTrue(titleRow.acceptsFirstResponder)
        XCTAssertGreaterThanOrEqual(titleRow.frame.height, 22)
        XCTAssertLessThanOrEqual(titleRow.frame.height, 28)
        XCTAssertEqual(usageRow.depth, 1)
    }

    func testOutlineSelectionAppliesActiveStateAndRerenderClearsIt() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-reader-active-\(UUID().uuidString).md")
        try "# Title\n\n## Usage\n".write(to: file, atomically: true, encoding: .utf8)
        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: file)
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let titleRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first { $0.title == "Title" })
        titleRow.performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let activeTitleRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first { $0.title == "Title" })
        XCTAssertTrue(activeTitleRow.isActive)

        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let rerenderedTitleRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first { $0.title == "Title" })
        XCTAssertFalse(rerenderedTitleRow.isActive)
    }

    func testNonLatinOutlineSelectionActivatesOnlyClickedHeading() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-reader-non-latin-active-\(UUID().uuidString).md")
        try "# mdreview\n\n## 使用\n\n## 开发\n".write(to: file, atomically: true, encoding: .utf8)
        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: file)
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let usageRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first { $0.title == "使用" })
        usageRow.performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let rows = findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView)
        let activeTitles = rows.filter(\.isActive).map(\.title)
        XCTAssertEqual(activeTitles, ["使用"])
    }

    func testActiveSidebarRowsUseSubtleReaderSelection() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-reader-subtle-selection-\(UUID().uuidString).md")
        try "# Title\n\n## Usage\n".write(to: file, atomically: true, encoding: .utf8)
        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: file)
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let titleRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first { $0.title == "Title" })
        titleRow.performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let activeTitleRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first { $0.title == "Title" })
        XCTAssertTrue(activeTitleRow.isActive)
        XCTAssertLessThanOrEqual(activeTitleRow.layer?.backgroundColor?.alpha ?? 1, 0.12)
    }

    func testDirectoryModeFilesUseTextRowsAndActiveFileState() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-files-\(UUID().uuidString)", isDirectory: true)
        let nested = root.appendingPathComponent("guide/advanced", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appendingPathComponent("Intro.md")
        try "# Intro\n".write(to: file, atomically: true, encoding: .utf8)

        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: file)
        let tree = [
            MarkdownNode(
                type: .directory,
                name: "guide",
                path: "guide",
                children: [
                    MarkdownNode(
                        type: .directory,
                        name: "advanced",
                        path: "guide/advanced",
                        children: [
                            MarkdownNode(type: .file, name: "Intro.md", path: "guide/advanced/Intro.md", children: [])
                        ]
                    )
                ]
            )
        ]

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: tree,
                tabs: [tab],
                activeTabID: tab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let fileRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "guide/advanced/Intro.md"
        })
        XCTAssertEqual(fileRow.title, "Intro.md")
        XCTAssertEqual(fileRow.depth, 2)
        XCTAssertTrue(fileRow.isActive)
        XCTAssertEqual(fileRow.accessibilityLabel(), "Intro.md")

        let advancedLabel = try XCTUnwrap(findSubviews(ofType: NSTextField.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "directory:guide/advanced"
        })
        XCTAssertEqual(advancedLabel.stringValue, "advanced")
        XCTAssertEqual(advancedLabel.tag, 1)
    }

    func testDocumentTabsUseLowChromeTextButtons() {
        let controller = MainWindowController()
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let first = DocumentTab(url: URL(fileURLWithPath: "/tmp/README.md"))
        let second = DocumentTab(url: URL(fileURLWithPath: "/tmp/Guide.md"))
        controller.apply(windowModel: WindowModel(tabs: [first, second], activeTabID: second.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let tabs = findSubviews(ofType: DocumentTabButton.self, in: controller.window?.contentView)
        let active = tabs.first { $0.title == "Guide.md" }
        let inactive = tabs.first { $0.title == "README.md" }

        XCTAssertEqual(tabs.count, 2)
        XCTAssertFalse(active?.isBordered ?? true)
        XCTAssertEqual(active?.bezelStyle, .regularSquare)
        XCTAssertEqual(active?.isActive, true)
        XCTAssertEqual(inactive?.isActive, false)
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
