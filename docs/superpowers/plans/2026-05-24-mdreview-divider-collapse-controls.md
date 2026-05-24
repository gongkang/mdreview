# mdreview Divider Collapse Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the sidebar collapse interaction discoverable by adding small divider-centered collapse and expand controls for the file list and outline panes.

**Architecture:** Keep the existing three-pane `NSSplitView` and the existing per-window collapse state in `MainWindowController`. Remove the old rail-only button from `SidebarPaneView`; the collapsed rail remains as layout surface only. Add two overlay `NSButton` controls in `MainWindowController`, centered on the file and outline divider positions, so clicking the control toggles collapse while dragging outside the control still uses native split-view resizing.

**Tech Stack:** Swift 6, AppKit, `NSSplitView`, `NSButton`, Auto Layout, XCTest, Swift Package Manager.

---

## Scope Check

This plan implements the refined design in `docs/superpowers/specs/2026-05-24-mdreview-sidebar-collapse-design.md`.

Covered requirements:

- Expanded folder-mode file list shows a divider-centered "收起文件列表" control.
- Expanded folder-mode outline shows a divider-centered "收起大纲" control.
- Collapsed file list and outline expose matching "展开..." controls in the same divider-centered area.
- Single-file mode hides the file-list control and keeps the outline control available.
- Divider controls use the same state transitions as existing View menu actions.
- Buttons are small, around `22px`, so the rest of the divider remains draggable.
- Existing width restore behavior and same-layout preservation remain intact.

Out of scope:

- Renaming View menu items.
- Persisting collapsed state.
- Changing default split ratios.
- Replacing native `NSSplitView` divider behavior.

## File Structure

- Modify `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
  - Add failing tests for visible expanded-state collapse controls.
  - Add failing tests that clicking divider controls collapses and expands the target pane.
  - Add a single-file test proving the file-list control is absent and the outline control remains.

- Modify `native/Sources/MdreviewApp/SidebarController.swift`
  - Simplify `SidebarPaneView` so it only switches between expanded content and collapsed rail.
  - Remove rail-only button state and rail button callbacks.

- Modify `native/Sources/MdreviewApp/MainWindowController.swift`
  - Add overlay divider buttons anchored to `filesContainer.trailingAnchor` and `outlineContainer.trailingAnchor`.
  - Route button actions through `toggleFiles()` and `toggleOutline()`.
  - Update button labels, symbols, visibility, and tooltips whenever collapse state or layout mode changes.

---

### Task 1: Add Failing Tests for Divider Controls

**Files:**
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add expanded-state divider control tests**

Add these tests above `private func findSubview<T: NSView>(ofType type: T.Type, in view: NSView?) -> T?`:

```swift
func testFolderModeShowsDividerCenteredCollapseControls() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let root = URL(fileURLWithPath: "/tmp/mdreview-divider-controls")
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
    let fileCollapse = try XCTUnwrap(visibleButton(label: "收起文件列表", in: controller.window?.contentView))
    let outlineCollapse = try XCTUnwrap(visibleButton(label: "收起大纲", in: controller.window?.contentView))

    let fileFrame = fileCollapse.convert(fileCollapse.bounds, to: splitView)
    let outlineFrame = outlineCollapse.convert(outlineCollapse.bounds, to: splitView)

    XCTAssertEqual(fileCollapse.frame.width, 22, accuracy: 1)
    XCTAssertEqual(fileCollapse.frame.height, 22, accuracy: 1)
    XCTAssertEqual(outlineCollapse.frame.width, 22, accuracy: 1)
    XCTAssertEqual(outlineCollapse.frame.height, 22, accuracy: 1)
    XCTAssertEqual(fileFrame.midY, splitView.bounds.midY, accuracy: 2)
    XCTAssertEqual(outlineFrame.midY, splitView.bounds.midY, accuracy: 2)
}

func testDividerControlCollapsesAndExpandsFileList() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let root = URL(fileURLWithPath: "/tmp/mdreview-divider-controls")
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

    try XCTUnwrap(visibleButton(label: "收起文件列表", in: controller.window?.contentView)).performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(splitView.subviews[0].frame.width, 28, accuracy: 2)

    try XCTUnwrap(visibleButton(label: "展开文件列表", in: controller.window?.contentView)).performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(splitView.subviews[0].frame.width, 260, accuracy: 3)
}

func testDividerControlCollapsesAndExpandsOutline() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let root = URL(fileURLWithPath: "/tmp/mdreview-divider-controls")
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

    try XCTUnwrap(visibleButton(label: "收起大纲", in: controller.window?.contentView)).performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(splitView.subviews[1].frame.width, 28, accuracy: 2)

    try XCTUnwrap(visibleButton(label: "展开大纲", in: controller.window?.contentView)).performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(splitView.subviews[1].frame.width, 210, accuracy: 3)
}

func testSingleFileModeShowsOnlyOutlineDividerControl() throws {
    let controller = MainWindowController(visibleFrame: NSRect(x: 20, y: 30, width: 1200, height: 800))
    defer { controller.window?.close() }
    controller.showWindow(nil)

    let tab = DocumentTab(url: URL(fileURLWithPath: "/tmp/README.md"))
    controller.apply(windowModel: WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument))
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))

    XCTAssertNil(visibleButton(label: "收起文件列表", in: controller.window?.contentView))
    XCTAssertNil(visibleButton(label: "展开文件列表", in: controller.window?.contentView))

    try XCTUnwrap(visibleButton(label: "收起大纲", in: controller.window?.contentView)).performClick(nil)
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertTrue(splitView.subviews[0].isHidden)
    XCTAssertEqual(splitView.subviews[1].frame.width, 28, accuracy: 2)
    XCTAssertNotNil(visibleButton(label: "展开大纲", in: controller.window?.contentView))
}
```

- [ ] **Step 2: Add a visible button helper**

Add this helper above `private func findSubview<T: NSView>(ofType type: T.Type, in view: NSView?) -> T?`:

```swift
private func visibleButton(label: String, in view: NSView?) -> NSButton? {
    findSubviews(ofType: NSButton.self, in: view).first {
        !$0.isHidden && $0.accessibilityLabel() == label
    }
}
```

- [ ] **Step 3: Run focused native tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: FAIL. The current implementation has `"展开..."` buttons only after collapse and does not expose visible `"收起文件列表"` or `"收起大纲"` divider controls in expanded state.

---

### Task 2: Remove Rail-Only Button from Sidebar Pane

**Files:**
- Modify: `native/Sources/MdreviewApp/SidebarController.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Simplify container initializers**

In `SidebarController`, replace the `filesContainer` and `outlineContainer` property definitions with:

```swift
private(set) lazy var filesContainer = SidebarPaneView(contentView: filesView)
private(set) lazy var outlineContainer = SidebarPaneView(contentView: outlineView)
```

Remove these properties:

```swift
var onExpandFiles: (() -> Void)?
var onExpandOutline: (() -> Void)?
```

- [ ] **Step 2: Remove rail callback methods**

Delete these methods from `SidebarController`:

```swift
@objc private func expandFilesFromRail() {
    onExpandFiles?()
}

@objc private func expandOutlineFromRail() {
    onExpandOutline?()
}
```

- [ ] **Step 3: Replace `SidebarPaneView` with a rail-only layout surface**

Replace the whole `SidebarPaneView` class with:

```swift
@MainActor
final class SidebarPaneView: NSView {
    static let collapsedWidth: CGFloat = 28

    private let contentView: NSView
    private let railView = NSView()
    private(set) var isCollapsed = false

    init(contentView: NSView) {
        self.contentView = contentView
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        railView.translatesAutoresizingMaskIntoConstraints = false
        railView.wantsLayer = true

        addSubview(contentView)
        addSubview(railView)

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            railView.leadingAnchor.constraint(equalTo: leadingAnchor),
            railView.trailingAnchor.constraint(equalTo: trailingAnchor),
            railView.topAnchor.constraint(equalTo: topAnchor),
            railView.bottomAnchor.constraint(equalTo: bottomAnchor)
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

Expected: FAIL at compile time because `MainWindowController` still assigns `sidebar.onExpandFiles` and `sidebar.onExpandOutline`. This confirms all rail-only callbacks have been removed from `SidebarController`.

---

### Task 3: Add Divider Overlay Controls in Main Window

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add divider button properties**

Add these properties after `private let splitView = NSSplitView()`:

```swift
private lazy var fileDividerButton = makeDividerButton(action: #selector(toggleFilesFromDivider))
private lazy var outlineDividerButton = makeDividerButton(action: #selector(toggleOutlineFromDivider))
```

- [ ] **Step 2: Add divider buttons to the window root**

In `buildLayout()`, after:

```swift
root.addSubview(tabBar.view)
root.addSubview(splitView)
```

add:

```swift
root.addSubview(fileDividerButton)
root.addSubview(outlineDividerButton)
```

In the same method, remove this old rail callback block:

```swift
sidebar.onExpandFiles = { [weak self] in
    self?.expandFiles()
}
sidebar.onExpandOutline = { [weak self] in
    self?.expandOutline()
}
```

- [ ] **Step 3: Add divider button constraints**

After this existing arranged-subview block:

```swift
splitView.addArrangedSubview(sidebar.filesContainer)
splitView.addArrangedSubview(sidebar.outlineContainer)
splitView.addArrangedSubview(renderer.view)
```

add:

```swift
NSLayoutConstraint.activate([
    fileDividerButton.centerXAnchor.constraint(equalTo: sidebar.filesContainer.trailingAnchor),
    fileDividerButton.centerYAnchor.constraint(equalTo: splitView.centerYAnchor),
    fileDividerButton.widthAnchor.constraint(equalToConstant: 22),
    fileDividerButton.heightAnchor.constraint(equalToConstant: 22),

    outlineDividerButton.centerXAnchor.constraint(equalTo: sidebar.outlineContainer.trailingAnchor),
    outlineDividerButton.centerYAnchor.constraint(equalTo: splitView.centerYAnchor),
    outlineDividerButton.widthAnchor.constraint(equalToConstant: 22),
    outlineDividerButton.heightAnchor.constraint(equalToConstant: 22)
])
```

- [ ] **Step 4: Add divider button construction and actions**

Add these methods below `buildLayout()`:

```swift
private func makeDividerButton(action: Selector) -> NSButton {
    let button = NSButton()
    button.translatesAutoresizingMaskIntoConstraints = false
    button.target = self
    button.action = action
    button.setButtonType(.momentaryChange)
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.imagePosition = .imageOnly
    button.focusRingType = .none
    button.wantsLayer = true
    button.layer?.cornerRadius = 11
    button.layer?.borderWidth = 0.5
    button.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    button.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
    button.contentTintColor = .secondaryLabelColor
    button.isHidden = true
    return button
}

@objc private func toggleFilesFromDivider() {
    toggleFiles()
}

@objc private func toggleOutlineFromDivider() {
    toggleOutline()
}
```

- [ ] **Step 5: Add divider button state updates**

Add these methods below `resetCollapsedState(for:)`:

```swift
private func updateDividerControls(for layoutMode: LayoutMode? = nil) {
    let mode = layoutMode ?? currentWindowModel?.layoutMode

    if mode == .filesOutlineAndDocument {
        fileDividerButton.isHidden = false
        configureDividerButton(
            fileDividerButton,
            collapsed: isFilesCollapsed,
            collapseLabel: "收起文件列表",
            expandLabel: "展开文件列表"
        )
    } else {
        clearDividerButton(fileDividerButton)
    }

    if mode == nil {
        clearDividerButton(outlineDividerButton)
    } else {
        outlineDividerButton.isHidden = false
        configureDividerButton(
            outlineDividerButton,
            collapsed: isOutlineCollapsed,
            collapseLabel: "收起大纲",
            expandLabel: "展开大纲"
        )
    }
}

private func configureDividerButton(_ button: NSButton, collapsed: Bool, collapseLabel: String, expandLabel: String) {
    let label = collapsed ? expandLabel : collapseLabel
    let symbolName = collapsed ? "chevron.right" : "chevron.left"
    button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    button.setAccessibilityLabel(label)
    button.toolTip = label
}

private func clearDividerButton(_ button: NSButton) {
    button.isHidden = true
    button.image = nil
    button.setAccessibilityLabel(nil)
    button.toolTip = nil
}
```

- [ ] **Step 6: Call divider state updates from existing flow**

In `buildLayout()`, after `tabBar.onSelectTab = ...`, add:

```swift
updateDividerControls()
```

In `apply(windowModel:)`, after:

```swift
applyDefaultSplitRatioIfNeeded(for: windowModel.layoutMode, force: shouldApplyDefaultRatio)
```

add:

```swift
updateDividerControls(for: windowModel.layoutMode)
```

In `resetCollapsedState(for:)`, add this as the last line:

```swift
updateDividerControls(for: layoutMode)
```

In `collapseFiles()`, `expandFiles()`, `collapseOutline()`, and `expandOutline()`, add this line after the relevant `sidebar.set...Collapsed(...)` call:

```swift
updateDividerControls()
```

- [ ] **Step 7: Run focused native tests and verify GREEN**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: PASS for `MainWindowLayoutTests`. The old rail-expand tests should continue to pass because they find the new divider-centered `"展开..."` buttons after collapse.

- [ ] **Step 8: Commit the divider controls implementation**

Run:

```bash
git add native/Sources/MdreviewApp/SidebarController.swift native/Sources/MdreviewApp/MainWindowController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "feat: add divider-centered sidebar controls"
```

Expected: commit succeeds and does not include the unrelated `.gitignore` change.

---

### Task 4: Verify Menu Compatibility and Full Test Suite

**Files:**
- Test: `native/Tests/MdreviewAppTests/AppMenuTests.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Run menu tests**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path native --filter AppMenuTests
```

Expected: PASS. Existing View menu actions still target `AppDelegate.toggleFiles` and `AppDelegate.toggleOutline`, and those still call the same `MainWindowController.toggle...` methods used by divider controls.

- [ ] **Step 2: Run all verification**

Run:

```bash
npm run test:all
```

Expected: PASS for TypeScript typecheck, Vitest tests, and native Swift tests.

---

### Task 5: Package and Manually Verify the Native App

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

- [ ] **Step 2: Verify folder-mode divider controls**

Run:

```bash
pkill -x mdreview-app || true
mdreview docs/superpowers --new-window
```

Expected:

- The file list, outline, and document are visible.
- A small control is visible at the middle of the file-list / outline divider.
- A small control is visible at the middle of the outline / document divider.
- Clicking the file-list divider control collapses the file list to a 28px rail.
- Clicking the same control again expands the file list.
- Clicking the outline divider control collapses the outline to a 28px rail.
- Clicking the same control again expands the outline.
- Dragging the divider above or below the button still resizes columns.

- [ ] **Step 3: Verify single-file divider controls**

Run:

```bash
pkill -x mdreview-app || true
mdreview README.md --new-window
```

Expected:

- The file list is hidden.
- No file-list divider control is visible.
- The outline divider control is visible.
- Clicking the outline divider control collapses and expands the outline.
- `视图 > 显示/隐藏文件` still does not reveal a file list in single-file mode.

- [ ] **Step 4: Check final git status**

Run:

```bash
git status --short
```

Expected: only the pre-existing unrelated `.gitignore` change may remain outside the implementation commits.
