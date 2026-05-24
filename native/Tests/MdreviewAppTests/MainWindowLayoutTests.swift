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

    func testDirectoryModeStartsWithApprovedSplitRatio() throws {
        let controller = MainWindowController(
            visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800),
            settings: AppSettings(
                openFoldersInNewWindow: false,
                autoRefreshSingleFile: true,
                restoreLastWindow: false,
                filesWidth: 500,
                outlineWidth: 400,
                showFiles: true,
                showOutline: true
            )
        )
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-layout")
        let tab = DocumentTab(url: root.appendingPathComponent("README.md"))
        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: [MarkdownNode(type: .file, name: "README.md", path: "README.md", children: [])],
                tabs: [tab],
                activeTabID: tab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        let files = splitView.subviews[0]
        let outline = splitView.subviews[1]
        let document = splitView.subviews[2]
        let contentWidth = files.frame.width + outline.frame.width + document.frame.width

        XCTAssertFalse(files.isHidden)
        XCTAssertFalse(outline.isHidden)
        XCTAssertEqual(files.frame.width / contentWidth, 0.17, accuracy: 0.04)
        XCTAssertEqual(outline.frame.width / contentWidth, 0.14, accuracy: 0.04)
        XCTAssertEqual(document.frame.width / contentWidth, 0.69, accuracy: 0.05)
    }

    func testSingleFileModeStartsWithApprovedSplitRatio() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: URL(fileURLWithPath: "/tmp/README.md"))
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        let files = splitView.subviews[0]
        let outline = splitView.subviews[1]
        let document = splitView.subviews[2]
        let visibleWidth = outline.frame.width + document.frame.width

        XCTAssertTrue(files.isHidden)
        XCTAssertFalse(outline.isHidden)
        XCTAssertEqual(outline.frame.width / visibleWidth, 0.16, accuracy: 0.04)
        XCTAssertEqual(document.frame.width / visibleWidth, 0.84, accuracy: 0.04)
    }

    func testDividerMovementIsNotResetForSameLayoutMode() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-layout")
        let first = DocumentTab(url: root.appendingPathComponent("README.md"))
        let second = DocumentTab(url: root.appendingPathComponent("Guide.md"))
        let tree = [
            MarkdownNode(type: .file, name: "README.md", path: "README.md", children: []),
            MarkdownNode(type: .file, name: "Guide.md", path: "Guide.md", children: [])
        ]

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: tree,
                tabs: [first],
                activeTabID: first.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        splitView.setPosition(300, ofDividerAt: 0)
        splitView.setPosition(520, ofDividerAt: 1)
        splitView.layoutSubtreeIfNeeded()
        let filesWidth = splitView.subviews[0].frame.width
        let outlineWidth = splitView.subviews[1].frame.width

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: tree,
                tabs: [second],
                activeTabID: second.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(splitView.subviews[0].frame.width, filesWidth, accuracy: 3)
        XCTAssertEqual(splitView.subviews[1].frame.width, outlineWidth, accuracy: 3)
    }

    func testLayoutModeChangeReappliesModeDefaultRatio() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-layout")
        let directoryTab = DocumentTab(url: root.appendingPathComponent("README.md"))
        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: [MarkdownNode(type: .file, name: "README.md", path: "README.md", children: [])],
                tabs: [directoryTab],
                activeTabID: directoryTab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        splitView.setPosition(360, ofDividerAt: 0)
        splitView.setPosition(620, ofDividerAt: 1)
        splitView.layoutSubtreeIfNeeded()

        let fileTab = DocumentTab(url: URL(fileURLWithPath: "/tmp/Standalone.md"))
        controller.apply(windowModel: WindowModel(tabs: [fileTab], activeTabID: fileTab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let outline = splitView.subviews[1]
        let document = splitView.subviews[2]
        let visibleWidth = outline.frame.width + document.frame.width

        XCTAssertTrue(splitView.subviews[0].isHidden)
        XCTAssertEqual(outline.frame.width / visibleWidth, 0.16, accuracy: 0.04)
    }

    func testMainWindowInitializesToVisibleFrameWithoutFullScreen() {
        let visibleFrame = NSRect(x: 12, y: 34, width: 1440, height: 900)
        let controller = MainWindowController(visibleFrame: visibleFrame)
        defer { controller.window?.close() }

        XCTAssertEqual(controller.window?.frame.origin.x ?? 0, visibleFrame.origin.x, accuracy: 1)
        XCTAssertEqual(controller.window?.frame.origin.y ?? 0, visibleFrame.origin.y, accuracy: 1)
        XCTAssertEqual(controller.window?.frame.width ?? 0, visibleFrame.width, accuracy: 1)
        XCTAssertEqual(controller.window?.frame.height ?? 0, visibleFrame.height, accuracy: 1)
        XCTAssertFalse(controller.window?.styleMask.contains(.fullScreen) ?? true)
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
