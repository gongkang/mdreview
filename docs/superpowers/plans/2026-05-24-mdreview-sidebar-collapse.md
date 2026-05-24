# mdreview Sidebar Collapse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add native expand and collapse interactions for the file list and outline navigation areas while preserving draggable split-view behavior.

**Architecture:** Keep `MainWindowController` responsible for split-view divider positions and temporary per-window widths. Add a lightweight `SidebarPaneView` container in `SidebarController.swift` so each navigation column can switch between expanded content and a 28px collapsed rail without changing the split view's three arranged subviews. Route both the visible rail buttons and existing View menu actions through the same `MainWindowController.toggleFiles()` and `MainWindowController.toggleOutline()` methods.

**Tech Stack:** Swift 6, AppKit, `NSSplitView`, `NSScrollView`, `NSButton`, XCTest, Swift Package Manager.

---

## Scope Check

This plan implements one cohesive UI interaction from `docs/superpowers/specs/2026-05-24-mdreview-sidebar-collapse-design.md`.

Covered requirements:

- Folder mode allows independent file-list and outline collapse and expand.
- Single-file mode hides the file list and allows only outline collapse and expand.
- Collapsed navigation columns remain visible as a 28px rail with an expand button.
- Expanded columns restore the last per-window width after collapse.
- View menu toggle actions use the same state transitions as rail buttons.
- Reapplying a `WindowModel` in the same layout mode does not reset collapsed state.
- Switching layout mode applies the existing default split-ratio behavior.
- No persisted settings are added for collapsed state or widths.

Out of scope:

- Renaming existing menu labels.
- Persisting collapsed state.
- Changing Markdown rendering, outline parsing, file scanning, or CLI arguments.

## File Structure

- Modify `native/Sources/MdreviewApp/SidebarController.swift`
  - Add `SidebarPaneView`.
  - Expose `filesContainer` and `outlineContainer` for split-view arranged subviews.
  - Keep `filesView` and `outlineView` as scroll views used for rendering content.
  - Add `setFilesCollapsed(_:)`, `setOutlineCollapsed(_:)`, `onExpandFiles`, and `onExpandOutline`.

- Modify `native/Sources/MdreviewApp/MainWindowController.swift`
  - Add collapse state and last expanded width state.
  - Add collapsed rail width constant.
  - Use sidebar containers in the split view.
  - Reset collapse state on layout-mode changes.
  - Implement collapse and expand divider movement.
  - Keep single-file file-list toggle as a no-op.

- Modify `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
  - Add regression tests for file-list collapse and expand.
  - Add regression tests for outline collapse and expand.
  - Add regression tests for single-file mode.
  - Add regression tests for same-layout reapply behavior.

---

### Task 1: Write Failing Collapse Tests

**Files:**
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add regression tests above the helper methods**

Add these tests above `private func findSubview<T: NSView>(ofType type: T.Type, in view: NSView?) -> T?`:

```swift
func testFolderModeFileListCollapsesToRailAndExpandsToPreviousWidth() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let root = URL(fileURLWithPath: "/tmp/mdreview-collapse")
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
    splitView.setPosition(260, ofDividerAt: 0)
    splitView.setPosition(460, ofDividerAt: 1)
    splitView.layoutSubtreeIfNeeded()

    controller.toggleFiles()
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertFalse(splitView.subviews[0].isHidden)
    XCTAssertFalse(splitView.subviews[1].isHidden)
    XCTAssertEqual(splitView.subviews[0].frame.width, 28, accuracy: 2)
    XCTAssertGreaterThan(splitView.subviews[1].frame.width, 180)
    XCTAssertGreaterThan(splitView.subviews[2].frame.width, 500)

    let expandButton = try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
        $0.accessibilityLabel() == "展开文件列表"
    })
    expandButton.performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(splitView.subviews[0].frame.width, 260, accuracy: 3)
}

func testFolderModeOutlineCollapsesToRailAndExpandsToPreviousWidth() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let root = URL(fileURLWithPath: "/tmp/mdreview-collapse")
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
    splitView.setPosition(240, ofDividerAt: 0)
    splitView.setPosition(450, ofDividerAt: 1)
    splitView.layoutSubtreeIfNeeded()

    controller.toggleOutline()
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertFalse(splitView.subviews[0].isHidden)
    XCTAssertFalse(splitView.subviews[1].isHidden)
    XCTAssertEqual(splitView.subviews[0].frame.width, 240, accuracy: 3)
    XCTAssertEqual(splitView.subviews[1].frame.width, 28, accuracy: 2)
    XCTAssertGreaterThan(splitView.subviews[2].frame.width, 700)

    let expandButton = try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
        $0.accessibilityLabel() == "展开大纲"
    })
    expandButton.performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(splitView.subviews[1].frame.width, 210, accuracy: 3)
}

func testSingleFileOutlineCollapsesWithoutShowingFileRail() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let tab = DocumentTab(url: URL(fileURLWithPath: "/tmp/README.md"))
    controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
    splitView.setPosition(0, ofDividerAt: 0)
    splitView.setPosition(220, ofDividerAt: 1)
    splitView.layoutSubtreeIfNeeded()

    controller.toggleFiles()
    controller.toggleOutline()
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertTrue(splitView.subviews[0].isHidden)
    XCTAssertFalse(splitView.subviews[1].isHidden)
    XCTAssertEqual(splitView.subviews[1].frame.width, 28, accuracy: 2)
    XCTAssertNil(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
        $0.accessibilityLabel() == "展开文件列表"
    })

    let expandButton = try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
        $0.accessibilityLabel() == "展开大纲"
    })
    expandButton.performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(splitView.subviews[1].frame.width, 220, accuracy: 3)
}

func testSameLayoutApplyKeepsFileListCollapsed() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let root = URL(fileURLWithPath: "/tmp/mdreview-collapse")
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
    controller.toggleFiles()
    controller.window?.contentView?.layoutSubtreeIfNeeded()

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

    let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
    XCTAssertFalse(splitView.subviews[0].isHidden)
    XCTAssertEqual(splitView.subviews[0].frame.width, 28, accuracy: 2)
    XCTAssertNotNil(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
        $0.accessibilityLabel() == "展开文件列表"
    })
}
```

- [ ] **Step 2: Run focused native tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: FAIL. At least one new test fails because the current implementation hides scroll views directly and does not create rail buttons with accessibility labels `"展开文件列表"` or `"展开大纲"`.

---

### Task 2: Add Collapsible Sidebar Pane Containers

**Files:**
- Modify: `native/Sources/MdreviewApp/SidebarController.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add pane state and callbacks to `SidebarController`**

Replace the top property block in `SidebarController` with:

```swift
let filesView: NSScrollView = SidebarScrollView()
let outlineView: NSScrollView = SidebarScrollView()
private(set) lazy var filesContainer = SidebarPaneView(
    contentView: filesView,
    expandAccessibilityLabel: "展开文件列表",
    target: self,
    action: #selector(expandFilesFromRail)
)
private(set) lazy var outlineContainer = SidebarPaneView(
    contentView: outlineView,
    expandAccessibilityLabel: "展开大纲",
    target: self,
    action: #selector(expandOutlineFromRail)
)
private let filesStack = SidebarStackView()
private let outlineStack = SidebarStackView()
private var outlineItems = [NativeOutlineItem]()
private var activeHeadingID: String?
var onSelectFile: ((String) -> Void)?
var onSelectHeading: ((String) -> Void)?
var onExpandFiles: (() -> Void)?
var onExpandOutline: (() -> Void)?
```

- [ ] **Step 2: Update sidebar layout-mode and collapse methods**

Replace `apply(layoutMode:)`, `toggleFiles()`, and `toggleOutline()` with:

```swift
func apply(layoutMode: LayoutMode) {
    filesContainer.isHidden = layoutMode == .outlineAndDocument
    if layoutMode == .outlineAndDocument {
        filesContainer.setCollapsed(false)
    }
}

func setFilesCollapsed(_ collapsed: Bool) {
    filesContainer.setCollapsed(collapsed)
}

func setOutlineCollapsed(_ collapsed: Bool) {
    outlineContainer.setCollapsed(collapsed)
}

func toggleFiles() {
    setFilesCollapsed(!filesContainer.isCollapsed)
}

func toggleOutline() {
    setOutlineCollapsed(!outlineContainer.isCollapsed)
}
```

Add these action methods near `selectFile(_:)`:

```swift
@objc private func expandFilesFromRail() {
    onExpandFiles?()
}

@objc private func expandOutlineFromRail() {
    onExpandOutline?()
}
```

- [ ] **Step 3: Add `SidebarPaneView` to the bottom of `SidebarController.swift`**

Add this class after `SidebarScrollView`:

```swift
@MainActor
final class SidebarPaneView: NSView {
    static let collapsedWidth: CGFloat = 28

    private let contentView: NSView
    private let railView = NSView()
    private let expandButton = NSButton()
    private(set) var isCollapsed = false

    init(contentView: NSView, expandAccessibilityLabel: String, target: AnyObject?, action: Selector) {
        self.contentView = contentView
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        railView.translatesAutoresizingMaskIntoConstraints = false
        railView.wantsLayer = true

        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.target = target
        expandButton.action = action
        expandButton.isBordered = false
        expandButton.bezelStyle = .regularSquare
        expandButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        expandButton.imagePosition = .imageOnly
        expandButton.setAccessibilityLabel(expandAccessibilityLabel)
        expandButton.toolTip = expandAccessibilityLabel

        addSubview(contentView)
        addSubview(railView)
        railView.addSubview(expandButton)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            railView.leadingAnchor.constraint(equalTo: leadingAnchor),
            railView.trailingAnchor.constraint(equalTo: trailingAnchor),
            railView.topAnchor.constraint(equalTo: topAnchor),
            railView.bottomAnchor.constraint(equalTo: bottomAnchor),

            expandButton.centerXAnchor.constraint(equalTo: railView.centerXAnchor),
            expandButton.topAnchor.constraint(equalTo: railView.topAnchor, constant: 10),
            expandButton.widthAnchor.constraint(equalToConstant: 22),
            expandButton.heightAnchor.constraint(equalToConstant: 22)
        ])

        setCollapsed(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setCollapsed(_ collapsed: Bool) {
        isCollapsed = collapsed
        contentView.isHidden = collapsed
        railView.isHidden = !collapsed
        needsLayout = true
    }
}
```

- [ ] **Step 4: Run focused native tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: FAIL. The new pane containers exist, but `MainWindowController` still adds the raw scroll views to the split view and still uses direct sidebar toggles.

---

### Task 3: Route Split View Through Pane Containers

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add collapse state to `MainWindowController`**

Add these properties below `private var isDeferringSplitRatioApplication = false`:

```swift
private var isFilesCollapsed = false
private var isOutlineCollapsed = false
private var lastExpandedFilesWidth: CGFloat?
private var lastExpandedOutlineWidth: CGFloat?
```

Add this enum below `SplitRatio`:

```swift
private enum SidebarCollapse {
    static let railWidth: CGFloat = SidebarPaneView.collapsedWidth
}
```

- [ ] **Step 2: Add pane containers to the split view**

In `buildLayout()`, replace:

```swift
sidebar.filesView.translatesAutoresizingMaskIntoConstraints = false
sidebar.outlineView.translatesAutoresizingMaskIntoConstraints = false
renderer.view.translatesAutoresizingMaskIntoConstraints = false
splitView.addArrangedSubview(sidebar.filesView)
splitView.addArrangedSubview(sidebar.outlineView)
splitView.addArrangedSubview(renderer.view)
```

with:

```swift
sidebar.filesContainer.translatesAutoresizingMaskIntoConstraints = false
sidebar.outlineContainer.translatesAutoresizingMaskIntoConstraints = false
renderer.view.translatesAutoresizingMaskIntoConstraints = false
splitView.addArrangedSubview(sidebar.filesContainer)
splitView.addArrangedSubview(sidebar.outlineContainer)
splitView.addArrangedSubview(renderer.view)
```

- [ ] **Step 3: Connect rail buttons to expand actions**

In `buildLayout()`, after `sidebar.onSelectHeading = ...`, add:

```swift
sidebar.onExpandFiles = { [weak self] in
    self?.expandFiles()
}
sidebar.onExpandOutline = { [weak self] in
    self?.expandOutline()
}
```

- [ ] **Step 4: Reset collapse state on layout-mode changes**

In `apply(windowModel:)`, keep this existing line:

```swift
let shouldApplyDefaultRatio = lastAppliedLayoutMode != windowModel.layoutMode
```

Immediately after `sidebar.apply(layoutMode: windowModel.layoutMode)`, add:

```swift
if shouldApplyDefaultRatio {
    resetCollapsedState(for: windowModel.layoutMode)
}
```

Add this helper below `apply(windowModel:)`:

```swift
private func resetCollapsedState(for layoutMode: LayoutMode) {
    isFilesCollapsed = false
    isOutlineCollapsed = false
    lastExpandedFilesWidth = nil
    lastExpandedOutlineWidth = nil
    sidebar.setFilesCollapsed(false)
    sidebar.setOutlineCollapsed(false)
    if layoutMode == .outlineAndDocument {
        sidebar.filesContainer.isHidden = true
    }
}
```

- [ ] **Step 5: Update default-ratio code to use pane containers**

In `applyDefaultSplitRatioIfNeeded(for:force:)`, replace the `switch layoutMode` block with:

```swift
switch layoutMode {
case .filesOutlineAndDocument:
    sidebar.filesContainer.isHidden = false
    splitView.setPosition(totalWidth * SplitRatio.folderFiles, ofDividerAt: 0)
    splitView.setPosition(totalWidth * (SplitRatio.folderFiles + SplitRatio.folderOutline), ofDividerAt: 1)
    splitView.setPosition(totalWidth * SplitRatio.folderFiles, ofDividerAt: 0)
case .outlineAndDocument:
    sidebar.filesContainer.isHidden = true
    splitView.setPosition(0, ofDividerAt: 0)
    splitView.setPosition(totalWidth * SplitRatio.singleFileOutline, ofDividerAt: 1)
}
```

- [ ] **Step 6: Run focused native tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: FAIL. The rail buttons are now in the view tree, but `toggleFiles()` and `toggleOutline()` still do not move dividers to 28px or restore widths.

---

### Task 4: Implement Collapse and Expand Divider Movement

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Replace the toggle methods**

Replace:

```swift
func toggleFiles() {
    sidebar.toggleFiles()
}

func toggleOutline() {
    sidebar.toggleOutline()
}
```

with:

```swift
func toggleFiles() {
    guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
    if isFilesCollapsed {
        expandFiles()
    } else {
        collapseFiles()
    }
}

func toggleOutline() {
    if isOutlineCollapsed {
        expandOutline()
    } else {
        collapseOutline()
    }
}
```

- [ ] **Step 2: Add collapse and expand helpers**

Add these helpers below the toggle methods:

```swift
private func collapseFiles() {
    guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
    guard !isFilesCollapsed else { return }
    splitView.layoutSubtreeIfNeeded()
    let currentWidth = splitView.subviews[0].frame.width
    if currentWidth > SidebarCollapse.railWidth {
        lastExpandedFilesWidth = currentWidth
    }
    isFilesCollapsed = true
    sidebar.setFilesCollapsed(true)
    splitView.setPosition(SidebarCollapse.railWidth, ofDividerAt: 0)
    splitView.layoutSubtreeIfNeeded()
}

private func expandFiles() {
    guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
    guard isFilesCollapsed else { return }
    splitView.layoutSubtreeIfNeeded()
    let targetWidth = lastExpandedFilesWidth ?? splitView.bounds.width * SplitRatio.folderFiles
    isFilesCollapsed = false
    sidebar.setFilesCollapsed(false)
    splitView.setPosition(targetWidth, ofDividerAt: 0)
    splitView.layoutSubtreeIfNeeded()
}

private func collapseOutline() {
    guard !isOutlineCollapsed else { return }
    splitView.layoutSubtreeIfNeeded()
    let currentWidth = splitView.subviews[1].frame.width
    if currentWidth > SidebarCollapse.railWidth {
        lastExpandedOutlineWidth = currentWidth
    }
    isOutlineCollapsed = true
    sidebar.setOutlineCollapsed(true)
    setOutlineWidth(SidebarCollapse.railWidth)
}

private func expandOutline() {
    guard isOutlineCollapsed else { return }
    splitView.layoutSubtreeIfNeeded()
    let targetWidth: CGFloat
    if let lastExpandedOutlineWidth {
        targetWidth = lastExpandedOutlineWidth
    } else if currentWindowModel?.layoutMode == .filesOutlineAndDocument {
        targetWidth = splitView.bounds.width * SplitRatio.folderOutline
    } else {
        targetWidth = splitView.bounds.width * SplitRatio.singleFileOutline
    }
    isOutlineCollapsed = false
    sidebar.setOutlineCollapsed(false)
    setOutlineWidth(targetWidth)
}

private func setOutlineWidth(_ outlineWidth: CGFloat) {
    splitView.layoutSubtreeIfNeeded()
    if currentWindowModel?.layoutMode == .outlineAndDocument {
        sidebar.filesContainer.isHidden = true
        splitView.setPosition(0, ofDividerAt: 0)
        splitView.setPosition(outlineWidth, ofDividerAt: 1)
    } else {
        let filesWidth = splitView.subviews[0].frame.width
        splitView.setPosition(filesWidth + outlineWidth, ofDividerAt: 1)
    }
    splitView.layoutSubtreeIfNeeded()
}
```

- [ ] **Step 3: Preserve collapse state during same-layout applies**

Confirm `applyDefaultSplitRatioIfNeeded(for:force:)` still starts with:

```swift
guard force else { return }
```

No extra code is needed for same-layout applies because `shouldApplyDefaultRatio` is `false`, and `resetCollapsedState(for:)` runs only on layout-mode changes.

- [ ] **Step 4: Run focused native tests and verify GREEN**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: PASS for `MainWindowLayoutTests`.

- [ ] **Step 5: Commit the tested implementation**

Run:

```bash
git add native/Sources/MdreviewApp/SidebarController.swift native/Sources/MdreviewApp/MainWindowController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "feat: add collapsible sidebar panes"
```

Expected: commit succeeds and does not include the unrelated `.gitignore` change.

---

### Task 5: Verify Menu Routing and Full Test Suite

**Files:**
- Test: `native/Tests/MdreviewAppTests/AppMenuTests.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add a menu selector regression test**

Append this test to `AppMenuTests`:

```swift
func testViewMenuUsesSidebarToggleActions() throws {
    let delegate = AppDelegate()
    let menu = delegate.buildMenu()
    let viewMenu = try XCTUnwrap(menu.item(withTitle: MenuText.view)?.submenu)

    let filesItem = try XCTUnwrap(viewMenu.item(withTitle: MenuText.toggleFiles))
    let outlineItem = try XCTUnwrap(viewMenu.item(withTitle: MenuText.toggleOutline))

    XCTAssertEqual(NSStringFromSelector(try XCTUnwrap(filesItem.action)), "toggleFiles")
    XCTAssertEqual(NSStringFromSelector(try XCTUnwrap(outlineItem.action)), "toggleOutline")
    XCTAssertTrue(try XCTUnwrap(filesItem.target as AnyObject?) === delegate)
    XCTAssertTrue(try XCTUnwrap(outlineItem.target as AnyObject?) === delegate)
}
```

- [ ] **Step 2: Run menu tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter AppMenuTests
```

Expected: PASS. The menu items already call `AppDelegate.toggleFiles` and `AppDelegate.toggleOutline`; those methods now reach the new collapse logic through `MainWindowController`.

- [ ] **Step 3: Run all verification**

Run:

```bash
npm run test:all
```

Expected: PASS for TypeScript typecheck, Vitest tests, and native Swift tests.

- [ ] **Step 4: Commit the menu regression test**

Run:

```bash
git add native/Tests/MdreviewAppTests/AppMenuTests.swift
git commit -m "test: cover sidebar toggle menu routing"
```

Expected: commit succeeds and does not include the unrelated `.gitignore` change.

---

### Task 6: Package and Manually Verify the Native App

**Files:**
- No source files changed in this task.

- [ ] **Step 1: Install local app and CLI**

Run:

```bash
npm run install:local
```

Expected output includes:

```text
Created native/dist/mdreview.app
已安装 App：
已注册命令：mdreview
```

- [ ] **Step 2: Verify folder-mode behavior**

Run:

```bash
osascript -e 'quit app "mdreview"' || true
mdreview docs/superpowers --new-window
```

Expected:

- The app opens maximized.
- The file list, outline, and document are visible.
- Using `视图 > 显示/隐藏文件` collapses the file list to a 28px rail.
- Clicking the file-list rail expands it.
- Using `视图 > 显示/隐藏大纲` collapses the outline to a 28px rail.
- Clicking the outline rail expands it.
- Dragging a sidebar, collapsing it, and expanding it restores the dragged width.

- [ ] **Step 3: Verify single-file behavior**

Run:

```bash
osascript -e 'quit app "mdreview"' || true
mdreview README.md --new-window
```

Expected:

- The file list is hidden.
- No file-list rail is visible.
- The outline can collapse to a 28px rail.
- Clicking the outline rail expands it.
- `视图 > 显示/隐藏文件` does not reveal a file list in single-file mode.

- [ ] **Step 4: Check final git status**

Run:

```bash
git status --short
```

Expected: only the pre-existing unrelated `.gitignore` change may remain outside the implementation commits.
