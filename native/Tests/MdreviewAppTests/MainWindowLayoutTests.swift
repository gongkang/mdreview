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

    func testSidebarNavigationRowsUseReadableFontSize() throws {
        let fileRow = SidebarRowButton(
            title: "README.md",
            identifier: "README.md",
            depth: 0,
            isActive: false,
            kind: .file,
            target: nil,
            action: #selector(NSButton.performClick(_:))
        )
        let outlineRow = SidebarRowButton(
            title: "Overview",
            identifier: "overview",
            depth: 0,
            isActive: false,
            kind: .outline,
            target: nil,
            action: #selector(NSButton.performClick(_:))
        )
        let directoryRow = SidebarDirectoryRowButton(
            title: "docs",
            identifier: "directory:docs",
            depth: 0,
            isExpanded: true,
            target: nil,
            action: #selector(NSButton.performClick(_:))
        )

        XCTAssertEqual(try fontSize(of: fileRow), 14)
        XCTAssertEqual(try fontSize(of: outlineRow), 14)
        XCTAssertEqual(try fontSize(of: directoryRow), 14)
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

        let advancedLabel = try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "directory:guide/advanced"
        })
        XCTAssertEqual(advancedLabel.accessibilityLabel(), "advanced")
        XCTAssertEqual(advancedLabel.tag, 1)
    }

    func testFileTreeDefaultsToCurrentBranchAndCollapsesOtherDirectories() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-collapsed-files")
        let activePath = "weekly/current/1126.md"
        let fileTree = [
            MarkdownNode(
                type: .directory,
                name: "weekly",
                path: "weekly",
                children: [
                    MarkdownNode(
                        type: .directory,
                        name: "current",
                        path: "weekly/current",
                        children: [
                            MarkdownNode(type: .file, name: "1126.md", path: activePath, children: [])
                        ]
                    ),
                    MarkdownNode(
                        type: .directory,
                        name: "archive",
                        path: "weekly/archive",
                        children: [
                            MarkdownNode(type: .file, name: "0105.md", path: "weekly/archive/0105.md", children: [])
                        ]
                    )
                ]
            )
        ]
        let tab = DocumentTab(url: root.appendingPathComponent(activePath))

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: fileTree,
                tabs: [tab],
                activeTabID: tab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let directoryButtons = findSubviews(ofType: NSButton.self, in: controller.window?.contentView)
        let weekly = try XCTUnwrap(directoryButtons.first { $0.identifier?.rawValue == "directory:weekly" })
        let current = try XCTUnwrap(directoryButtons.first { $0.identifier?.rawValue == "directory:weekly/current" })
        let archive = try XCTUnwrap(directoryButtons.first { $0.identifier?.rawValue == "directory:weekly/archive" })

        XCTAssertEqual(weekly.accessibilityLabel(), "weekly")
        XCTAssertEqual(current.accessibilityLabel(), "current")
        XCTAssertEqual(archive.accessibilityLabel(), "archive")
        XCTAssertNotNil(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == activePath
        })
        XCTAssertNil(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "weekly/archive/0105.md"
        })
    }

    func testDirectoryRowsToggleExpansion() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-toggle-files")
        let activePath = "weekly/current/1126.md"
        let archivedPath = "weekly/archive/0105.md"
        let fileTree = [
            MarkdownNode(
                type: .directory,
                name: "weekly",
                path: "weekly",
                children: [
                    MarkdownNode(
                        type: .directory,
                        name: "current",
                        path: "weekly/current",
                        children: [MarkdownNode(type: .file, name: "1126.md", path: activePath, children: [])]
                    ),
                    MarkdownNode(
                        type: .directory,
                        name: "archive",
                        path: "weekly/archive",
                        children: [MarkdownNode(type: .file, name: "0105.md", path: archivedPath, children: [])]
                    )
                ]
            )
        ]
        let tab = DocumentTab(url: root.appendingPathComponent(activePath))

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: fileTree,
                tabs: [tab],
                activeTabID: tab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertNil(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == archivedPath
        })

        try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "directory:weekly/archive"
        }).performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertNotNil(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == archivedPath
        })

        try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "directory:weekly/archive"
        }).performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertNil(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == archivedPath
        })
    }

    func testDirectoryDisclosureSymbolDoesNotAccumulateAcrossAppearanceUpdates() {
        let row = SidebarDirectoryRowButton(
            title: "技术咨询",
            identifier: "directory:technical",
            depth: 0,
            isExpanded: false,
            target: nil,
            action: #selector(NSButton.performClick(_:))
        )

        XCTAssertEqual(row.attributedTitle.string, "▸ 技术咨询")

        row.isExpanded = true
        XCTAssertEqual(row.attributedTitle.string, "▾ 技术咨询")

        row.isExpanded = false
        XCTAssertEqual(row.attributedTitle.string, "▸ 技术咨询")

        row.isExpanded = true
        XCTAssertEqual(row.attributedTitle.string, "▾ 技术咨询")
    }

    func testFileTreeKeepsUserExpansionWhenActiveFileChanges() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-remember-expanded-files")
        let activePath = "weekly/current/1126.md"
        let archivedPath = "weekly/archive/0105.md"
        let fileTree = [
            MarkdownNode(
                type: .directory,
                name: "weekly",
                path: "weekly",
                children: [
                    MarkdownNode(
                        type: .directory,
                        name: "current",
                        path: "weekly/current",
                        children: [MarkdownNode(type: .file, name: "1126.md", path: activePath, children: [])]
                    ),
                    MarkdownNode(
                        type: .directory,
                        name: "archive",
                        path: "weekly/archive",
                        children: [MarkdownNode(type: .file, name: "0105.md", path: archivedPath, children: [])]
                    )
                ]
            )
        ]
        let currentTab = DocumentTab(url: root.appendingPathComponent(activePath))
        let otherTab = DocumentTab(url: root.appendingPathComponent("other.md"))

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: fileTree,
                tabs: [currentTab, otherTab],
                activeTabID: currentTab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "directory:weekly/archive"
        }).performClick(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: fileTree,
                tabs: [currentTab, otherTab],
                activeTabID: otherTab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        XCTAssertNotNil(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == archivedPath
        })
    }

    func testDeepFileTreeUsesBoundedReadableIndentation() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-deep-files")
        let directoryNames = (0..<12).map { "folder-level-\($0)-with-readable-name" }
        let fileName = "final-readable-file-name.md"
        let filePath = (directoryNames + [fileName]).joined(separator: "/")
        let deepestDirectoryPath = directoryNames.joined(separator: "/")
        var node = MarkdownNode(type: .file, name: fileName, path: filePath, children: [])
        for index in stride(from: directoryNames.count - 1, through: 0, by: -1) {
            let directoryPath = directoryNames[0...index].joined(separator: "/")
            node = MarkdownNode(
                type: .directory,
                name: directoryNames[index],
                path: directoryPath,
                children: [node]
            )
        }

        let tab = DocumentTab(url: root.appendingPathComponent(filePath))
        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: [node],
                tabs: [tab],
                activeTabID: tab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let fileRow = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == filePath
        })
        let fileStyle = try XCTUnwrap(fileRow.attributedTitle.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(fileRow.depth, directoryNames.count)
        XCTAssertEqual(fileStyle.lineBreakMode, .byTruncatingTail)
        XCTAssertLessThanOrEqual(fileStyle.firstLineHeadIndent, 84)

        let deepestDirectoryLabel = try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
            $0.identifier?.rawValue == "directory:\(deepestDirectoryPath)"
        })
        let directoryStyle = try XCTUnwrap(deepestDirectoryLabel.attributedTitle.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(deepestDirectoryLabel.accessibilityLabel(), directoryNames.last)
        XCTAssertEqual(deepestDirectoryLabel.tag, directoryNames.count - 1)
        XCTAssertEqual(directoryStyle.lineBreakMode, .byTruncatingTail)
        XCTAssertLessThanOrEqual(directoryStyle.firstLineHeadIndent, 84)
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

    func testPinnedFileDirectoryKeepsLongFileNamesFromExpandingListWidth() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-long-file-name")
        let longName = "2026-05-24-mdreview-hover-drawer-outline-navigation-and-split-layout-regression-plan-with-extra-long-title.md"
        let tab = DocumentTab(url: root.appendingPathComponent(longName))
        controller.apply(
            windowModel: WindowModel(
                workspaceRoot: root,
                fileTree: [MarkdownNode(type: .file, name: longName, path: longName, children: [])],
                tabs: [tab],
                activeTabID: tab.id,
                layoutMode: .filesOutlineAndDocument
            )
        )
        controller.pinFileDirectoryForTesting()
        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        splitView.setPosition(240, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let filesPane = splitView.subviews[0]
        let filesScrollView = try XCTUnwrap(findSubview(ofType: NSScrollView.self, in: filesPane))
        let documentWidth = try XCTUnwrap(filesScrollView.documentView?.frame.width)
        let clipWidth = filesScrollView.contentView.bounds.width

        XCTAssertLessThanOrEqual(documentWidth, clipWidth + 1)
    }

    func testSidebarListsKeepLeadingAlignmentWhenWidthIsClamped() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-leading-sidebar")
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
        controller.pinFileDirectoryForTesting()
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        let filesStack = try XCTUnwrap(findSubview(ofType: NSScrollView.self, in: splitView.subviews[0])?.documentView as? NSStackView)
        let outlineStack = try XCTUnwrap(findSubview(ofType: NSScrollView.self, in: splitView.subviews[1])?.documentView as? NSStackView)

        XCTAssertEqual(filesStack.alignment, .leading)
        XCTAssertEqual(outlineStack.alignment, .leading)
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

    func testPinnedFileDirectoryWidthDoesNotGrowWhenSelectingFilesFromDirectoryRows() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-pin-selection-growth")
        let readme = DocumentTab(url: root.appendingPathComponent("README.md"))
        let implementation = DocumentTab(url: root.appendingPathComponent("2026-05-24-mdreview-hover-drawer-outline-nav-design.md"))
        let reader = DocumentTab(url: root.appendingPathComponent("2026-05-22-mdreview-native-app-design.md"))
        let fileTree = [
            MarkdownNode(type: .file, name: "README.md", path: "README.md", children: []),
            MarkdownNode(
                type: .file,
                name: "2026-05-24-mdreview-hover-drawer-outline-nav-design.md",
                path: "2026-05-24-mdreview-hover-drawer-outline-nav-design.md",
                children: []
            ),
            MarkdownNode(
                type: .file,
                name: "2026-05-22-mdreview-native-app-design.md",
                path: "2026-05-22-mdreview-native-app-design.md",
                children: []
            )
        ]
        var model = WindowModel(
            workspaceRoot: root,
            fileTree: fileTree,
            tabs: [readme],
            activeTabID: readme.id,
            layoutMode: .filesOutlineAndDocument
        )
        controller.onOpenWorkspaceFile = { url in
            if let existing = model.tabs.first(where: { $0.url.path == url.path }) {
                model.activeTabID = existing.id
            } else {
                let tab: DocumentTab
                if url.lastPathComponent == implementation.title {
                    tab = implementation
                } else if url.lastPathComponent == reader.title {
                    tab = reader
                } else {
                    tab = DocumentTab(url: url)
                }
                model.tabs.append(tab)
                model.activeTabID = tab.id
            }
            controller.apply(windowModel: model)
        }

        controller.apply(windowModel: model)
        controller.pinFileDirectoryForTesting()
        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        splitView.setPosition(300, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        let originalWidth = splitView.subviews[0].frame.width

        for identifier in [
            "2026-05-24-mdreview-hover-drawer-outline-nav-design.md",
            "2026-05-22-mdreview-native-app-design.md",
            "README.md",
            "2026-05-24-mdreview-hover-drawer-outline-nav-design.md"
        ] {
            let row = try XCTUnwrap(findSubviews(ofType: SidebarRowButton.self, in: controller.window?.contentView).first {
                $0.identifier?.rawValue == identifier
            })
            row.performClick(nil)
            controller.window?.contentView?.layoutSubtreeIfNeeded()

            XCTAssertEqual(splitView.subviews[0].frame.width, originalWidth, accuracy: 3)
        }
    }

    func testOpeningManyTabsDoesNotGrowPinnedDirectoryOrOutlineWidth() throws {
        let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1600, height: 900))
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let root = URL(fileURLWithPath: "/tmp/mdreview-many-tabs")
        let files = (0..<12).map { index in
            "Long tab title \(index) with enough words to pressure the tab bar.md"
        }
        let fileTree = files.map { MarkdownNode(type: .file, name: $0, path: $0, children: []) }
        let first = DocumentTab(url: root.appendingPathComponent(files[0]))
        var tabs = [first]
        var activeID = first.id

        func applyModel() {
            controller.apply(
                windowModel: WindowModel(
                    workspaceRoot: root,
                    fileTree: fileTree,
                    tabs: tabs,
                    activeTabID: activeID,
                    layoutMode: .filesOutlineAndDocument
                )
            )
            controller.window?.contentView?.layoutSubtreeIfNeeded()
        }

        applyModel()
        controller.pinFileDirectoryForTesting()
        let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
        splitView.setPosition(300, ofDividerAt: 0)
        splitView.setPosition(560, ofDividerAt: 1)
        splitView.layoutSubtreeIfNeeded()

        let originalFilesWidth = splitView.subviews[0].frame.width
        let originalOutlineWidth = splitView.subviews[1].frame.width

        for file in files.dropFirst() {
            let tab = DocumentTab(url: root.appendingPathComponent(file))
            tabs.append(tab)
            activeID = tab.id
            applyModel()

            XCTAssertEqual(splitView.subviews[0].frame.width, originalFilesWidth, accuracy: 3)
            XCTAssertEqual(splitView.subviews[1].frame.width, originalOutlineWidth, accuracy: 3)
        }
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

    private func fontSize(of button: NSButton) throws -> CGFloat {
        let font = try XCTUnwrap(button.attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        return font.pointSize
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
