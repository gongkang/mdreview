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

    func testNestedOutlineRowsUseReadablePrimaryTextColor() throws {
        let row = SidebarRowButton(
            title: "Nested heading",
            identifier: "nested-heading",
            depth: 3,
            isActive: false,
            kind: .outline,
            target: nil,
            action: #selector(NSButton.performClick(_:))
        )

        let color = try XCTUnwrap(row.attributedTitle.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        let rgb = try XCTUnwrap(color.usingColorSpace(.sRGB))

        XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.01)
        XCTAssertLessThan(rgb.redComponent, 0.25)
        XCTAssertLessThan(rgb.greenComponent, 0.25)
        XCTAssertLessThan(rgb.blueComponent, 0.25)
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
        controller.openFileDrawerForTesting()
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
        XCTAssertEqual(files.frame.width, 28, accuracy: 3)
        XCTAssertEqual(outline.frame.width / contentWidth, 0.20, accuracy: 0.04)
        XCTAssertEqual(document.frame.width / contentWidth, 0.75, accuracy: 0.05)
    }

    func testFolderModeStartsWithEdgeCollapsedFileDirectoryAndVisibleOutline() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-hover-drawer")
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

        XCTAssertEqual(controller.fileDirectoryModeForTesting, .edgeCollapsed)
        XCTAssertFalse(controller.isFileDrawerVisibleForTesting)
        XCTAssertTrue(controller.isOutlineVisibleForTesting)

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        XCTAssertEqual(splitView.subviews[0].frame.width, 28, accuracy: 3)
        XCTAssertFalse(splitView.subviews[0].isHidden)
        XCTAssertFalse(splitView.subviews[1].isHidden)
        XCTAssertGreaterThan(splitView.subviews[2].frame.width, 700)
    }

    func testCollapsedFileDirectoryUsesSubtleEdgeTrigger() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-subtle-edge")
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

        let edgeTrigger = try XCTUnwrap(findSubview(ofType: FileEdgeTriggerView.self, in: controller.window?.contentView))

        XCTAssertLessThanOrEqual(edgeTrigger.button.alphaValue, 0.45)
        XCTAssertLessThanOrEqual(edgeTrigger.button.frame.width, 24)
        XCTAssertLessThanOrEqual(edgeTrigger.button.frame.height, 24)
    }

    func testSingleFileModeDoesNotShowFileDirectoryTrigger() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: URL(fileURLWithPath: "/tmp/README.md"))
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertTrue(controller.isSingleFileFileDirectoryHiddenForTesting)
        XCTAssertNil(visibleButton(label: "打开文件列表", in: controller.window?.contentView))
        XCTAssertNil(visibleButton(label: "固定文件列表", in: controller.window?.contentView))
    }

    func testFileDirectoryHoverDrawerOpensAndClosesWithoutResizingDocument() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-hover-drawer")
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
        let documentMinX = splitView.subviews[2].frame.minX

        controller.openFileDrawerForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(controller.fileDirectoryModeForTesting, .hoverOpen)
        XCTAssertTrue(controller.isFileDrawerVisibleForTesting)
        XCTAssertEqual(splitView.subviews[2].frame.minX, documentMinX, accuracy: 2)
        XCTAssertNotNil(visibleButton(label: "固定文件列表", in: controller.window?.contentView))
        XCTAssertNil(visibleButton(label: "展开文件列表", in: controller.window?.contentView))
        XCTAssertNil(visibleButton(label: "收起文件列表", in: controller.window?.contentView))

        controller.closeFileDrawerForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(controller.fileDirectoryModeForTesting, .edgeCollapsed)
        XCTAssertFalse(controller.isFileDrawerVisibleForTesting)
        XCTAssertEqual(splitView.subviews[2].frame.minX, documentMinX, accuracy: 2)
    }

    func testPinnedFileDirectoryParticipatesInSplitLayoutAndRestoresWidth() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-pin")
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

        controller.openFileDrawerForTesting()
        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        XCTAssertEqual(controller.fileDirectoryModeForTesting, .pinned)
        XCTAssertFalse(controller.isFileDrawerVisibleForTesting)
        XCTAssertGreaterThan(splitView.subviews[0].frame.width, 240)
        XCTAssertNotNil(visibleButton(label: "取消固定文件列表", in: controller.window?.contentView))
        XCTAssertNil(visibleButton(label: "固定文件列表", in: controller.window?.contentView))
        XCTAssertNil(visibleButton(label: "展开文件列表", in: controller.window?.contentView))
        XCTAssertNil(visibleButton(label: "收起文件列表", in: controller.window?.contentView))

        splitView.setPosition(330, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        controller.toggleFiles()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(controller.fileDirectoryModeForTesting, .edgeCollapsed)
        XCTAssertEqual(splitView.subviews[0].frame.width, 28, accuracy: 3)

        controller.toggleFiles()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(controller.fileDirectoryModeForTesting, .pinned)
        XCTAssertEqual(splitView.subviews[0].frame.width, 330, accuracy: 4)
    }

    func testPinnedFileDirectoryUsesDocumentWhiteBackground() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-pin-white")
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

        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        let files = splitView.subviews[0]
        let color = try XCTUnwrap(files.layer?.backgroundColor.flatMap { NSColor(cgColor: $0) })
        let rgb = try XCTUnwrap(color.usingColorSpace(.sRGB))

        XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.01)
        XCTAssertGreaterThan(rgb.redComponent, 0.95)
        XCTAssertGreaterThan(rgb.greenComponent, 0.95)
        XCTAssertGreaterThan(rgb.blueComponent, 0.95)
    }

    func testPinnedFileDirectoryDrawsSubtleTrailingSeparator() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-pin-separator")
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

        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        let files = splitView.subviews[0]
        let separator = try XCTUnwrap(findSubview(withIdentifier: "file-directory-trailing-separator", in: files))
        let color = try XCTUnwrap(separator.layer?.backgroundColor.flatMap { NSColor(cgColor: $0) })

        XCTAssertFalse(separator.isHiddenOrHasHiddenAncestor)
        XCTAssertEqual(separator.frame.width, 1, accuracy: 0.5)
        XCTAssertEqual(separator.frame.maxX, files.bounds.maxX, accuracy: 1)
        XCTAssertGreaterThan(color.alphaComponent, 0.05)
        XCTAssertLessThan(color.alphaComponent, 0.35)
    }

    func testPinnedFileDirectoryStaysPinnedWhenSelectingAnotherFile() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-pin-selection")
        let readme = DocumentTab(url: root.appendingPathComponent("README.md"))
        let guide = DocumentTab(url: root.appendingPathComponent("Guide.md"))
        let fileTree = [
            MarkdownNode(type: .file, name: "README.md", path: "README.md", children: []),
            MarkdownNode(type: .file, name: "Guide.md", path: "Guide.md", children: [])
        ]
        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: fileTree,
                tabs: [readme, guide],
                activeTabID: readme.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        splitView.setPosition(330, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: fileTree,
                tabs: [readme, guide],
                activeTabID: guide.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(controller.fileDirectoryModeForTesting, .pinned)
        XCTAssertEqual(splitView.subviews[0].frame.width, 330, accuracy: 4)
        XCTAssertNotNil(visibleButton(label: "取消固定文件列表", in: controller.window?.contentView))
        XCTAssertNil(visibleButton(label: "打开文件列表", in: controller.window?.contentView))
    }

    func testFileMenuToggleDoesNotRevealFileDirectoryInSingleFileMode() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let tab = DocumentTab(url: URL(fileURLWithPath: "/tmp/README.md"))
        controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        controller.toggleFiles()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertTrue(controller.isSingleFileFileDirectoryHiddenForTesting)
        XCTAssertEqual(controller.fileDirectoryModeForTesting, .edgeCollapsed)
    }

    func testOutlineUsesContentAreaDirectoryToggle() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-outline-toggle")
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
        let document = splitView.subviews[2]
        let toggle = try XCTUnwrap(visibleButton(label: "隐藏目录", in: controller.window?.contentView))
        let toggleFrame = toggle.convert(toggle.bounds, to: splitView)

        XCTAssertGreaterThanOrEqual(toggleFrame.minX, document.frame.minX + 8)
        XCTAssertLessThanOrEqual(toggleFrame.minX, document.frame.minX + 42)
        XCTAssertEqual(toggleFrame.minY, 12, accuracy: 3)
        XCTAssertNil(visibleButton(label: "收起大纲", in: controller.window?.contentView))
    }

    func testWideOutlineFillsDraggedNavigationPane() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1400, height: 860))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-wide-outline")
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
        splitView.setPosition(28, ofDividerAt: 0)
        splitView.setPosition(720, ofDividerAt: 1)
        splitView.layoutSubtreeIfNeeded()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let outline = splitView.subviews[1]
        let outlineScroll = try XCTUnwrap(findSubviews(ofType: NSScrollView.self, in: outline).first)

        XCTAssertGreaterThan(outline.frame.width, 600)
        XCTAssertGreaterThan(outlineScroll.frame.width / outline.frame.width, 0.90)
        XCTAssertEqual(outlineScroll.frame.maxX, outline.bounds.maxX - 12, accuracy: 2)
    }

    func testOutlinePaneUsesDocumentWhiteBackground() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-white-outline")
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
        let outline = splitView.subviews[1]
        let color = try XCTUnwrap(outline.layer?.backgroundColor.flatMap { NSColor(cgColor: $0) })
        let rgb = try XCTUnwrap(color.usingColorSpace(.sRGB))

        XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.01)
        XCTAssertGreaterThan(rgb.redComponent, 0.95)
        XCTAssertGreaterThan(rgb.greenComponent, 0.95)
        XCTAssertGreaterThan(rgb.blueComponent, 0.95)
    }

    func testOutlineDirectoryToggleHidesAndRestoresPreviousWidth() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-outline-toggle")
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
        splitView.setPosition(28, ofDividerAt: 0)
        splitView.setPosition(300, ofDividerAt: 1)
        splitView.layoutSubtreeIfNeeded()
        let outlineWidth = splitView.subviews[1].frame.width

        try XCTUnwrap(visibleButton(label: "隐藏目录", in: controller.window?.contentView)).performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertFalse(controller.isOutlineVisibleForTesting)
        XCTAssertTrue(splitView.subviews[1].isHidden)
        XCTAssertNotNil(visibleButton(label: "显示目录", in: controller.window?.contentView))

        try XCTUnwrap(visibleButton(label: "显示目录", in: controller.window?.contentView)).performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertTrue(controller.isOutlineVisibleForTesting)
        XCTAssertFalse(splitView.subviews[1].isHidden)
        XCTAssertEqual(splitView.subviews[1].frame.width, outlineWidth, accuracy: 4)
    }

    func testOutlineDocumentSeparatorIsNotRendered() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-short-separator")
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

        XCTAssertNil(findSubview(withIdentifier: "outline-document-short-separator", in: controller.window?.contentView))
    }

    func testOutlineScrollersDoNotDrawPersistentDividerTracks() {
        let sidebar = SidebarController()

        XCTAssertTrue(sidebar.outlineView.hasVerticalScroller)
        XCTAssertTrue(sidebar.outlineView.autohidesScrollers)
        XCTAssertEqual(sidebar.outlineView.scrollerStyle, .overlay)
        XCTAssertFalse(sidebar.outlineView.drawsBackground)
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
        XCTAssertEqual(outline.frame.width / visibleWidth, 0.20, accuracy: 0.04)
        XCTAssertEqual(document.frame.width / visibleWidth, 0.80, accuracy: 0.04)
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
        XCTAssertEqual(outline.frame.width / visibleWidth, 0.20, accuracy: 0.04)
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

    func testSplitViewUsesThinVisualDividerWithWideDragArea() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-divider-style")
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

        XCTAssertEqual(splitView.dividerStyle, .thin)
        XCTAssertGreaterThanOrEqual(splitView.dividerThickness, 8)
    }

    private func visibleButton(label: String, in view: NSView?) -> NSButton? {
        findSubviews(ofType: NSButton.self, in: view).first {
            !$0.isHiddenOrHasHiddenAncestor && $0.accessibilityLabel() == label
        }
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

    private func findSubview(withIdentifier identifier: String, in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if view.identifier?.rawValue == identifier {
            return view
        }
        for subview in view.subviews {
            if let match = findSubview(withIdentifier: identifier, in: subview) {
                return match
            }
        }
        return nil
    }
}
