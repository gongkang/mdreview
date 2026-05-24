# mdreview Hover Drawer and Outline Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace divider-centered sidebar collapse controls with a left-edge file drawer and content-integrated outline navigation.

**Architecture:** Keep `MainWindowController` as the owner of layout state and split-view sizing. Move file-directory visibility into explicit states (`edgeCollapsed`, `hoverOpen`, `pinned`) and render the hover drawer as an overlay so quick file browsing does not resize the document. Treat outline as document navigation controlled by a content-area icon, with a short visual separator instead of a divider-centered control.

**Tech Stack:** Swift, AppKit, `NSSplitView`, `NSView`, `NSButton`, XCTest, existing `MdreviewCore` models.

---

## Preflight

The current workspace may already have uncommitted changes in:

- `native/Sources/MdreviewApp/MainWindowController.swift`
- `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

These are previous sidebar-collapse experiments. Do not discard them with `git checkout` or `git reset`. Replace the relevant divider-button behavior with the new hover drawer and outline navigation model.

Run before starting:

```bash
git status --short --branch
```

Expected: the branch may show local modifications. Continue only after reviewing the diff for the files you will edit:

```bash
git diff -- native/Sources/MdreviewApp/MainWindowController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
```

## File Structure

Modify these files:

- `native/Sources/MdreviewApp/MainWindowController.swift`
  - Owns `FileDirectoryMode`, outline visibility, split positioning, menu actions, drawer overlay wiring, and content-area outline toggle positioning.
- `native/Sources/MdreviewApp/SidebarController.swift`
  - Owns file tree and outline rendering views, file drawer chrome, edge trigger view, and outline navigation presentation.
- `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
  - Replaces old divider-control assertions with drawer, pinned pane, and outline-toggle assertions.
- `native/Tests/MdreviewAppTests/AppMenuTests.swift`
  - Keeps menu action wiring covered and adds expectations for file-list behavior in single-file mode if menu validation hooks are added.

Do not modify renderer Markdown code for this change.

## Task 1: Define New Layout State and Failing Tests

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add failing tests for folder-mode defaults**

Add these tests near the existing split-layout tests in `MainWindowLayoutTests.swift`. They intentionally reference accessors that do not exist yet.

```swift
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
    XCTAssertEqual(splitView.subviews[0].frame.width, 52, accuracy: 3)
    XCTAssertFalse(splitView.subviews[0].isHidden)
    XCTAssertFalse(splitView.subviews[1].isHidden)
    XCTAssertGreaterThan(splitView.subviews[2].frame.width, 700)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testFolderModeStartsWithEdgeCollapsedFileDirectoryAndVisibleOutline
xcrun swift test --package-path native --filter MainWindowLayoutTests/testSingleFileModeDoesNotShowFileDirectoryTrigger
```

Expected: compile failure because `fileDirectoryModeForTesting`, `isFileDrawerVisibleForTesting`, `isOutlineVisibleForTesting`, and `isSingleFileFileDirectoryHiddenForTesting` are not defined.

- [ ] **Step 3: Add the minimal state API**

In `MainWindowController.swift`, replace the old file/outline collapsed booleans with explicit state. Keep the old `toggleFiles()` and `toggleOutline()` public methods because `AppDelegate` already calls them.

```swift
enum FileDirectoryMode: Equatable {
    case edgeCollapsed
    case hoverOpen
    case pinned
}

private enum SplitRatio {
    static let fileEdge: CGFloat = 52
    static let pinnedFolderFiles: CGFloat = 0.24
    static let folderOutline: CGFloat = 0.20
    static let singleFileOutline: CGFloat = 0.20
}

private var fileDirectoryMode: FileDirectoryMode = .edgeCollapsed
private var isOutlineVisible = true
private var lastPinnedFilesWidth: CGFloat?
private var lastOutlineWidth: CGFloat?
```

Add test-only read accessors inside `MainWindowController`:

```swift
var fileDirectoryModeForTesting: FileDirectoryMode {
    fileDirectoryMode
}

var isFileDrawerVisibleForTesting: Bool {
    fileDirectoryMode == .hoverOpen
}

var isOutlineVisibleForTesting: Bool {
    isOutlineVisible
}

var isSingleFileFileDirectoryHiddenForTesting: Bool {
    guard currentWindowModel?.layoutMode == .outlineAndDocument else { return false }
    return sidebar.filesContainer.isHidden
}
```

Update `resetCollapsedState(for:)` into `resetNavigationState(for:)`:

```swift
private func resetNavigationState(for layoutMode: LayoutMode) {
    isOutlineVisible = true
    lastPinnedFilesWidth = nil
    lastOutlineWidth = nil

    switch layoutMode {
    case .filesOutlineAndDocument:
        fileDirectoryMode = .edgeCollapsed
        sidebar.filesContainer.isHidden = false
    case .outlineAndDocument:
        fileDirectoryMode = .edgeCollapsed
        sidebar.filesContainer.isHidden = true
    }

    sidebar.outlineContainer.isHidden = false
    updateNavigationControls()
}
```

In `apply(windowModel:)`, replace calls to `resetCollapsedState(for:)` and `updateDividerControls(for:)` with:

```swift
if shouldApplyDefaultRatio {
    resetNavigationState(for: windowModel.layoutMode)
}
applyDefaultSplitRatioIfNeeded(for: windowModel.layoutMode, force: shouldApplyDefaultRatio)
updateNavigationControls()
```

- [ ] **Step 4: Make default split ratios match the new state**

Change `applyDefaultSplitRatioIfNeeded(for:force:)` so folder mode starts with only the file edge visible.

```swift
switch layoutMode {
case .filesOutlineAndDocument:
    sidebar.filesContainer.isHidden = false
    sidebar.outlineContainer.isHidden = !isOutlineVisible
    splitView.setPosition(SplitRatio.fileEdge, ofDividerAt: 0)
    splitView.setPosition(SplitRatio.fileEdge + totalWidth * SplitRatio.folderOutline, ofDividerAt: 1)
case .outlineAndDocument:
    sidebar.filesContainer.isHidden = true
    sidebar.outlineContainer.isHidden = !isOutlineVisible
    splitView.setPosition(0, ofDividerAt: 0)
    splitView.setPosition(totalWidth * SplitRatio.singleFileOutline, ofDividerAt: 1)
}
```

- [ ] **Step 5: Run the new tests**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testFolderModeStartsWithEdgeCollapsedFileDirectoryAndVisibleOutline
xcrun swift test --package-path native --filter MainWindowLayoutTests/testSingleFileModeDoesNotShowFileDirectoryTrigger
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add native/Sources/MdreviewApp/MainWindowController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "test: define hover drawer navigation state"
```

## Task 2: Add File Edge Trigger and Hover Drawer Overlay

**Files:**
- Modify: `native/Sources/MdreviewApp/SidebarController.swift`
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add failing tests for hover open and close**

Add:

```swift
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
    XCTAssertNotNil(visibleButton(label: "收起文件列表", in: controller.window?.contentView))

    controller.closeFileDrawerForTesting()
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(controller.fileDirectoryModeForTesting, .edgeCollapsed)
    XCTAssertFalse(controller.isFileDrawerVisibleForTesting)
    XCTAssertEqual(splitView.subviews[2].frame.minX, documentMinX, accuracy: 2)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testFileDirectoryHoverDrawerOpensAndClosesWithoutResizingDocument
```

Expected: compile failure because drawer API and views do not exist.

- [ ] **Step 3: Add file directory chrome views**

In `SidebarController.swift`, add these view classes below `SidebarScrollView`.

```swift
@MainActor
final class FileEdgeTriggerView: NSView {
    let button = NSButton()
    var onOpen: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "打开文件列表")
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel("打开文件列表")
        button.toolTip = "打开文件列表"
        button.target = self
        button.action = #selector(open)
        addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        onOpen?()
    }

    @objc private func open() {
        onOpen?()
    }
}

@MainActor
final class FileDirectoryChromeView: NSView {
    let pinButton = NSButton()
    let expandButton = NSButton()
    let collapseButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "文件")
    private let contentSlot = NSView()
    private var hostedContent: NSView?
    var onPin: (() -> Void)?
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onMouseExit: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.22).cgColor
        layer?.borderWidth = 1

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor

        let actions = NSStackView()
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.orientation = .horizontal
        actions.spacing = 6

        configure(pinButton, symbol: "pin", label: "固定文件列表", action: #selector(pin))
        configure(expandButton, symbol: "arrow.up.left.and.arrow.down.right", label: "展开文件列表", action: #selector(expand))
        configure(collapseButton, symbol: "chevron.left", label: "收起文件列表", action: #selector(collapse))
        actions.addArrangedSubview(pinButton)
        actions.addArrangedSubview(expandButton)
        actions.addArrangedSubview(collapseButton)

        contentSlot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        addSubview(actions)
        addSubview(contentSlot)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            actions.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            actions.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            contentSlot.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentSlot.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentSlot.topAnchor.constraint(equalTo: topAnchor, constant: 46),
            contentSlot.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func host(_ view: NSView) {
        hostedContent?.removeFromSuperview()
        hostedContent = view
        view.translatesAutoresizingMaskIntoConstraints = false
        contentSlot.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentSlot.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentSlot.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentSlot.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentSlot.bottomAnchor)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExit?()
    }

    private func configure(_ button: NSButton, symbol: String, label: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.target = self
        button.action = action
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    @objc private func pin() { onPin?() }
    @objc private func expand() { onExpand?() }
    @objc private func collapse() { onCollapse?() }
}
```

- [ ] **Step 4: Expose the new views from `SidebarController`**

Replace `filesContainer` setup with edge and drawer-aware views:

```swift
let fileEdgeTriggerView = FileEdgeTriggerView()
let fileDrawerView = FileDirectoryChromeView()
private(set) lazy var filesContainer = FileDirectoryPaneView(edgeView: fileEdgeTriggerView)
private(set) lazy var outlineContainer = SidebarPaneView(contentView: outlineView)
```

Add:

```swift
func showFileDrawer(_ visible: Bool) {
    fileDrawerView.isHidden = !visible
    if visible {
        fileDrawerView.host(filesView)
    }
}

func showPinnedFilesPane() {
    filesContainer.host(filesView)
    filesContainer.setMode(.pinned)
    fileDrawerView.isHidden = true
}

func showFileEdgeTrigger() {
    filesContainer.setMode(.edge)
    fileDrawerView.isHidden = true
}

func configureFileDirectoryActions(
    open: @escaping () -> Void,
    pin: @escaping () -> Void,
    expand: @escaping () -> Void,
    collapse: @escaping () -> Void,
    drawerMouseExit: @escaping () -> Void
) {
    fileEdgeTriggerView.onOpen = open
    fileDrawerView.onPin = pin
    fileDrawerView.onExpand = expand
    fileDrawerView.onCollapse = collapse
    fileDrawerView.onMouseExit = drawerMouseExit
}
```

Replace `apply(layoutMode:)` in `SidebarController` so single-file mode keeps the file directory fully hidden:

```swift
func apply(layoutMode: LayoutMode) {
    switch layoutMode {
    case .filesOutlineAndDocument:
        filesContainer.isHidden = false
        showFileEdgeTrigger()
    case .outlineAndDocument:
        filesContainer.isHidden = true
        showFileDrawer(false)
    }
}
```

Add this replacement for `SidebarPaneView` file-container use:

```swift
@MainActor
final class FileDirectoryPaneView: NSView {
    enum Mode {
        case edge
        case pinned
    }

    private let edgeView: FileEdgeTriggerView
    private let contentSlot = NSView()
    private var hostedContent: NSView?
    private(set) var mode: Mode = .edge

    init(edgeView: FileEdgeTriggerView) {
        self.edgeView = edgeView
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        edgeView.translatesAutoresizingMaskIntoConstraints = false
        contentSlot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(edgeView)
        addSubview(contentSlot)
        NSLayoutConstraint.activate([
            edgeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            edgeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            edgeView.topAnchor.constraint(equalTo: topAnchor),
            edgeView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentSlot.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentSlot.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentSlot.topAnchor.constraint(equalTo: topAnchor),
            contentSlot.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setMode(.edge)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func host(_ view: NSView) {
        hostedContent?.removeFromSuperview()
        hostedContent = view
        view.translatesAutoresizingMaskIntoConstraints = false
        contentSlot.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentSlot.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentSlot.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentSlot.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentSlot.bottomAnchor)
        ])
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
        edgeView.isHidden = mode != .edge
        contentSlot.isHidden = mode != .pinned
    }
}
```

- [ ] **Step 5: Wire overlay into `MainWindowController`**

In `buildLayout()`, add the drawer overlay after `splitView` so it renders above the split content:

```swift
root.addSubview(splitView)
root.addSubview(sidebar.fileDrawerView)
```

Add constraints:

```swift
sidebar.fileDrawerView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
sidebar.fileDrawerView.topAnchor.constraint(equalTo: tabBar.view.bottomAnchor),
sidebar.fileDrawerView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
sidebar.fileDrawerView.widthAnchor.constraint(equalToConstant: 286)
```

Wire actions:

```swift
sidebar.configureFileDirectoryActions(
    open: { [weak self] in self?.openFileDrawer() },
    pin: { [weak self] in self?.pinFileDirectory() },
    expand: { [weak self] in self?.openFileDrawer() },
    collapse: { [weak self] in self?.collapseFileDirectoryToEdge() },
    drawerMouseExit: { [weak self] in self?.closeFileDrawerIfTemporary() }
)
```

Add:

```swift
func openFileDrawerForTesting() {
    openFileDrawer()
}

func closeFileDrawerForTesting() {
    closeFileDrawerIfTemporary()
}

private func openFileDrawer() {
    guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
    guard fileDirectoryMode != .pinned else { return }
    fileDirectoryMode = .hoverOpen
    sidebar.showFileDrawer(true)
    updateNavigationControls()
}

private func closeFileDrawerIfTemporary() {
    guard fileDirectoryMode == .hoverOpen else { return }
    fileDirectoryMode = .edgeCollapsed
    sidebar.showFileDrawer(false)
    updateNavigationControls()
}

private func collapseFileDirectoryToEdge() {
    guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
    fileDirectoryMode = .edgeCollapsed
    sidebar.showFileEdgeTrigger()
    sidebar.showFileDrawer(false)
    splitView.setPosition(SplitRatio.fileEdge, ofDividerAt: 0)
    splitView.layoutSubtreeIfNeeded()
    updateNavigationControls()
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testFileDirectoryHoverDrawerOpensAndClosesWithoutResizingDocument
xcrun swift test --package-path native --filter MainWindowLayoutTests/testFolderModeStartsWithEdgeCollapsedFileDirectoryAndVisibleOutline
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add native/Sources/MdreviewApp/SidebarController.swift native/Sources/MdreviewApp/MainWindowController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "feat: add hover file drawer"
```

## Task 3: Implement Pinned File Pane and Menu Toggle Semantics

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
- Modify: `native/Tests/MdreviewAppTests/AppMenuTests.swift`

- [ ] **Step 1: Add failing tests for pin, unpin, and menu behavior**

Add:

```swift
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

    splitView.setPosition(330, ofDividerAt: 0)
    splitView.layoutSubtreeIfNeeded()
    controller.toggleFiles()
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(controller.fileDirectoryModeForTesting, .edgeCollapsed)
    XCTAssertEqual(splitView.subviews[0].frame.width, 52, accuracy: 3)

    controller.toggleFiles()
    controller.window?.contentView?.layoutSubtreeIfNeeded()

    XCTAssertEqual(controller.fileDirectoryModeForTesting, .pinned)
    XCTAssertEqual(splitView.subviews[0].frame.width, 330, accuracy: 4)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testPinnedFileDirectoryParticipatesInSplitLayoutAndRestoresWidth
xcrun swift test --package-path native --filter MainWindowLayoutTests/testFileMenuToggleDoesNotRevealFileDirectoryInSingleFileMode
```

Expected: compile failure for `pinFileDirectoryForTesting` or assertion failure because pinning is not implemented.

- [ ] **Step 3: Implement pin and menu toggle**

Add testing method:

```swift
func pinFileDirectoryForTesting() {
    pinFileDirectory()
}
```

Replace `toggleFiles()` with:

```swift
func toggleFiles() {
    guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
    if fileDirectoryMode == .pinned {
        collapseFileDirectoryToEdge()
    } else {
        pinFileDirectory()
    }
}
```

Add:

```swift
private func pinFileDirectory() {
    guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
    splitView.layoutSubtreeIfNeeded()

    let targetWidth = lastPinnedFilesWidth ?? max(
        SplitRatio.fileEdge,
        splitView.bounds.width * SplitRatio.pinnedFolderFiles
    )
    fileDirectoryMode = .pinned
    sidebar.showPinnedFilesPane()
    sidebar.showFileDrawer(false)
    splitView.setPosition(targetWidth, ofDividerAt: 0)
    restoreOutlinePositionAfterFileWidthChange(fileWidth: targetWidth)
    splitView.layoutSubtreeIfNeeded()
    updateNavigationControls()
}

private func restoreOutlinePositionAfterFileWidthChange(fileWidth: CGFloat) {
    guard isOutlineVisible else { return }
    let outlineWidth = lastOutlineWidth ?? splitView.bounds.width * SplitRatio.folderOutline
    splitView.setPosition(fileWidth + outlineWidth, ofDividerAt: 1)
}
```

Update `collapseFileDirectoryToEdge()` to remember pinned width:

```swift
if fileDirectoryMode == .pinned {
    let currentWidth = splitView.subviews[0].frame.width
    if currentWidth > SplitRatio.fileEdge {
        lastPinnedFilesWidth = currentWidth
    }
}
```

- [ ] **Step 4: Update selected-file behavior**

In `buildLayout()`, update `sidebar.onSelectFile` so temporary drawer closes after file selection:

```swift
sidebar.onSelectFile = { [weak self] relativePath in
    guard let self, let root = self.currentWorkspaceRoot else { return }
    self.onOpenWorkspaceFile?(root.appendingPathComponent(relativePath))
    self.closeFileDrawerIfTemporary()
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testPinnedFileDirectoryParticipatesInSplitLayoutAndRestoresWidth
xcrun swift test --package-path native --filter MainWindowLayoutTests/testFileMenuToggleDoesNotRevealFileDirectoryInSingleFileMode
xcrun swift test --package-path native --filter AppMenuTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add native/Sources/MdreviewApp/MainWindowController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift native/Tests/MdreviewAppTests/AppMenuTests.swift
git commit -m "feat: support pinned file directory"
```

## Task 4: Replace Outline Divider Button with Content-Area Directory Icon

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Modify: `native/Sources/MdreviewApp/SidebarController.swift`
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add failing outline toggle tests**

Replace old tests named around divider controls with these:

```swift
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
    splitView.setPosition(52, ofDividerAt: 0)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testOutlineUsesContentAreaDirectoryToggle
xcrun swift test --package-path native --filter MainWindowLayoutTests/testOutlineDirectoryToggleHidesAndRestoresPreviousWidth
```

Expected: fail because the old `outlineDividerButton` still exists or has old labels.

- [ ] **Step 3: Replace outline divider button**

In `MainWindowController.swift`, replace:

```swift
private lazy var outlineDividerButton = makeDividerButton(action: #selector(toggleOutlineFromDivider))
```

with:

```swift
private lazy var outlineToggleButton = makeNavigationIconButton(
    symbolName: "list.bullet",
    action: #selector(toggleOutlineFromNavigationButton)
)
```

Add:

```swift
private func makeNavigationIconButton(symbolName: String, action: Selector) -> NSButton {
    let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
    button.translatesAutoresizingMaskIntoConstraints = true
    button.setButtonType(.momentaryChange)
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    button.imagePosition = .imageOnly
    button.target = self
    button.action = action
    return button
}

@objc private func toggleOutlineFromNavigationButton() {
    toggleOutline()
}
```

In `buildLayout()`, add `outlineToggleButton` to `root` instead of `outlineDividerButton`.

Replace `updateDividerControls()` with `updateNavigationControls()`:

```swift
private func updateNavigationControls() {
    let outlineLabel = isOutlineVisible ? "隐藏目录" : "显示目录"
    outlineToggleButton.isHidden = currentWindowModel == nil
    outlineToggleButton.setAccessibilityLabel(outlineLabel)
    outlineToggleButton.toolTip = outlineLabel
    layoutNavigationControls()
}
```

Add:

```swift
private func layoutNavigationControls() {
    guard !outlineToggleButton.isHidden, let root = window?.contentView else { return }
    let origin = splitView.convert(
        NSPoint(x: renderer.view.frame.minX + 14, y: 12 + outlineToggleButton.bounds.height),
        to: root
    )
    outlineToggleButton.frame = NSRect(
        x: round(origin.x),
        y: round(origin.y),
        width: outlineToggleButton.bounds.width,
        height: outlineToggleButton.bounds.height
    )
}
```

Replace the existing split-view delegate callback at the bottom of `MainWindowController.swift`:

```swift
extension MainWindowController: NSSplitViewDelegate {
    func splitViewDidResizeSubviews(_ notification: Notification) {
        layoutNavigationControls()
        layoutOutlineSeparator()
    }
}
```

- [ ] **Step 4: Implement outline show/hide**

Replace `toggleOutline()`, `collapseOutline()`, and `expandOutline()` with:

```swift
func toggleOutline() {
    if isOutlineVisible {
        hideOutlineNavigation()
    } else {
        showOutlineNavigation()
    }
}

private func hideOutlineNavigation() {
    guard isOutlineVisible else { return }
    splitView.layoutSubtreeIfNeeded()
    let currentWidth = splitView.subviews[1].frame.width
    if currentWidth > 0 {
        lastOutlineWidth = currentWidth
    }
    isOutlineVisible = false
    sidebar.outlineContainer.isHidden = true

    if currentWindowModel?.layoutMode == .outlineAndDocument {
        splitView.setPosition(0, ofDividerAt: 0)
        splitView.setPosition(0, ofDividerAt: 1)
    } else {
        let fileWidth = splitView.subviews[0].frame.width
        splitView.setPosition(fileWidth, ofDividerAt: 1)
    }

    splitView.layoutSubtreeIfNeeded()
    updateNavigationControls()
}

private func showOutlineNavigation() {
    guard !isOutlineVisible else { return }
    let targetWidth = lastOutlineWidth ?? splitView.bounds.width * (
        currentWindowModel?.layoutMode == .outlineAndDocument
            ? SplitRatio.singleFileOutline
            : SplitRatio.folderOutline
    )
    isOutlineVisible = true
    sidebar.outlineContainer.isHidden = false

    if currentWindowModel?.layoutMode == .outlineAndDocument {
        sidebar.filesContainer.isHidden = true
        splitView.setPosition(0, ofDividerAt: 0)
        splitView.setPosition(targetWidth, ofDividerAt: 1)
    } else {
        let fileWidth = splitView.subviews[0].frame.width
        splitView.setPosition(fileWidth + targetWidth, ofDividerAt: 1)
    }

    splitView.layoutSubtreeIfNeeded()
    updateNavigationControls()
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testOutlineUsesContentAreaDirectoryToggle
xcrun swift test --package-path native --filter MainWindowLayoutTests/testOutlineDirectoryToggleHidesAndRestoresPreviousWidth
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add native/Sources/MdreviewApp/MainWindowController.swift native/Sources/MdreviewApp/SidebarController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "feat: add content outline navigation toggle"
```

## Task 5: Add Short Outline Separator and Remove Old Divider Chrome

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Modify: `native/Sources/MdreviewApp/SidebarController.swift`
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add failing tests for short separator**

Add:

```swift
func testOutlineDocumentSeparatorIsShortAndSubtle() throws {
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

    let separator = try XCTUnwrap(findSubview(withIdentifier: "outline-document-short-separator", in: controller.window?.contentView))
    let splitView = try XCTUnwrap(findSubview(ofType: NSSplitView.self, in: controller.window?.contentView))
    let document = splitView.subviews[2]
    let separatorFrame = separator.convert(separator.bounds, to: splitView)

    XCTAssertEqual(separatorFrame.minX, document.frame.minX, accuracy: 4)
    XCTAssertLessThan(separatorFrame.height, splitView.frame.height * 0.45)
    XCTAssertGreaterThan(separatorFrame.height, 120)
    XCTAssertLessThanOrEqual(separatorFrame.width, 1)
}
```

Add helper:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests/testOutlineDocumentSeparatorIsShortAndSubtle
```

Expected: FAIL because separator view does not exist.

- [ ] **Step 3: Add separator view**

In `MainWindowController.swift`, add:

```swift
private let outlineDocumentSeparator = NSView()
```

In `buildLayout()` after adding `splitView`, add:

```swift
outlineDocumentSeparator.translatesAutoresizingMaskIntoConstraints = true
outlineDocumentSeparator.identifier = NSUserInterfaceItemIdentifier("outline-document-short-separator")
outlineDocumentSeparator.wantsLayer = true
outlineDocumentSeparator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.28).cgColor
root.addSubview(outlineDocumentSeparator)
```

Add:

```swift
private func layoutOutlineSeparator() {
    guard let root = window?.contentView else { return }
    guard isOutlineVisible, !sidebar.outlineContainer.isHidden else {
        outlineDocumentSeparator.isHidden = true
        return
    }
    outlineDocumentSeparator.isHidden = false
    let origin = splitView.convert(NSPoint(x: renderer.view.frame.minX, y: 92), to: root)
    outlineDocumentSeparator.frame = NSRect(
        x: round(origin.x),
        y: round(origin.y),
        width: 1,
        height: min(180, max(120, splitView.bounds.height * 0.28))
    )
}
```

Call `layoutOutlineSeparator()` from `layoutNavigationControls()`, after split ratio application, and after outline toggles.

- [ ] **Step 4: Remove old divider button classes and tests**

Delete these old concepts from `MainWindowController.swift`:

- `fileDividerButton`
- `outlineDividerButton`
- `DividerButton`
- `makeDividerButton`
- `layoutDividerButtons`
- `positionDividerButton`
- `toggleFilesFromDivider`
- `toggleOutlineFromDivider`
- `SidebarCollapse`
- `CollapseControl`

Keep `ReaderSplitView` only if its wide drag area is still needed. Change its drawing so it does not draw a strong full-height line:

```swift
override func drawDivider(in rect: NSRect) {
    NSColor.textBackgroundColor.setFill()
    rect.fill()
}
```

Remove or rewrite tests that assert:

- `"收起文件列表"` is centered on the divider.
- `"展开文件列表"` exists as a divider button.
- `"收起大纲"` exists as a divider button.
- Outline collapse leaves only split drag hot zones.

The replacement tests in Tasks 1-5 cover the new behavior.

- [ ] **Step 5: Run focused native layout tests**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: all `MainWindowLayoutTests` pass.

- [ ] **Step 6: Commit**

```bash
git add native/Sources/MdreviewApp/MainWindowController.swift native/Sources/MdreviewApp/SidebarController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "refactor: remove divider sidebar controls"
```

## Task 6: Full Verification and Manual App Check

**Files:**
- Modify if needed: `README.md`
- Modify if needed: `docs/superpowers/specs/2026-05-24-mdreview-hover-drawer-outline-nav-design.md`

- [ ] **Step 1: Run all automated tests**

Run:

```bash
npm run test:all
```

Expected:

- Web and Node tests pass.
- Native Swift tests pass.
- No failed XCTest cases.

- [ ] **Step 2: Build and install the app**

Run:

```bash
npm run build:app
node scripts/install-local.mjs
```

Expected:

- `native/dist/mdreview.app` is built.
- `/Users/kuchen/Applications/mdreview.app` is installed.
- `mdreview` command remains available.

- [ ] **Step 3: Manually verify folder mode**

Run:

```bash
pkill -x mdreview-app || true
mdreview docs/superpowers --new-window
```

Check:

- The file directory is not expanded by default.
- The left edge shows only the file-list trigger.
- Moving the mouse to the left edge opens the file drawer.
- Moving away closes the drawer when it is not pinned.
- Clicking `固定文件列表` makes the file pane persistent.
- Dragging the pinned file pane resizes it.
- `显示/隐藏文件列表` toggles pinned vs edge-collapsed mode.
- The outline is visible beside the document.
- The outline/document separator is a short subtle line.
- The content-area directory icon hides and shows the outline.

- [ ] **Step 4: Manually verify single-file mode**

Run:

```bash
pkill -x mdreview-app || true
mdreview README.md --new-window
```

Check:

- No file-directory trigger appears.
- No hover file drawer appears at the left edge.
- The content-area directory icon hides and shows the outline.
- The app menu remains Chinese.
- `Cmd+W` still closes the active tab/window according to existing behavior.

- [ ] **Step 5: Update docs only if user-facing usage changed**

If the README describes divider-centered collapse buttons, replace that text with:

```markdown
打开目录时，文件列表默认收起到窗口左侧边缘。将鼠标移到最左侧可以临时展开文件列表；固定后文件列表会变成可拖拽调整宽度的常驻栏。当前文档的大纲使用正文左上角的目录按钮显示或隐藏。
```

Run:

```bash
rg -n "分隔|收起|展开|文件列表|大纲|目录" README.md docs
```

Expected: no remaining docs describe divider-centered sidebar collapse controls as the current behavior.

- [ ] **Step 6: Final status check**

Run:

```bash
git status --short --branch
```

Expected: clean working tree or only deliberate documentation changes staged for the final commit.

- [ ] **Step 7: Final commit if docs changed**

If Step 5 changed docs:

```bash
git add README.md docs
git commit -m "docs: update navigation behavior"
```

If Step 5 did not change docs, do not create an empty commit.
