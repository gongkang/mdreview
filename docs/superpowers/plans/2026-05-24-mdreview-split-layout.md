# mdreview Split Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make native mdreview windows open maximized, use ratio-based draggable split layouts, center Settings on every open, remove active pixel-width settings, and add a Chinese Quit menu item.

**Architecture:** Keep `MainWindowController` as the owner of native window layout and `SidebarController` as the owner of sidebar row rendering. Replace fixed sidebar width constraints with one-shot `NSSplitView` divider positioning that runs for new windows and layout-mode changes only. Keep settings persistence intact for existing keys, but stop exposing or using sidebar pixel widths.

**Tech Stack:** Swift 6, AppKit, `NSSplitView`, `NSWindow`, XCTest, Swift Package Manager.

---

## Scope Check

This plan implements one cohesive native-window polish slice from `docs/superpowers/specs/2026-05-24-mdreview-split-layout-design.md`.

Covered requirements:

- Folder mode default ratio: file list `17%`, outline `14%`, document `69%`.
- Single-file mode default ratio: outline `16%`, document `84%`.
- Dividers are draggable and not pinned by fixed width constraints.
- Dragged widths apply only to the current window.
- Same-window document changes preserve divider positions when layout mode stays the same.
- Layout mode changes reapply that mode's default ratio.
- New document windows open maximized to the screen visible frame, not macOS full screen.
- Settings opens centered each time.
- Settings no longer shows sidebar pixel width controls.
- App menu includes `退出 mdreview` below `设置...`.

Out of scope:

- Removing stored `filesWidth` and `outlineWidth` keys from `AppSettings`.
- Changing Markdown rendering or file watching.
- Adding persistent per-workspace layout memory.

## File Structure

- Modify `native/Sources/MdreviewApp/MainWindowController.swift`
  - Main document window frame initialization.
  - Ratio constants and divider positioning.
  - Remove sidebar width constraints and renderer minimum width constraint.
  - Track last applied layout mode.

- Modify `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
  - Add native layout regression tests for ratios, dragging, preservation, and maximized window frame.

- Modify `native/Sources/MdreviewApp/SettingsWindowController.swift`
  - Remove active sidebar width controls from Settings UI.
  - Preserve old width values in saved settings.
  - Add `showCentered(relativeTo:)`.

- Modify `native/Sources/MdreviewApp/AppDelegate.swift`
  - Route Settings menu through `showCentered(relativeTo:)`.
  - Expose menu construction to app tests.
  - Add Quit item below Settings.

- Modify `native/Sources/MdreviewCore/MenuText.swift`
  - Add `quit` localized menu text.

- Modify `native/Tests/MdreviewCoreTests/MenuTextTests.swift`
  - Assert the new Chinese Quit label.

- Create `native/Tests/MdreviewAppTests/AppMenuTests.swift`
  - Assert app menu ordering, shortcut, action, and target.

- Create `native/Tests/MdreviewAppTests/SettingsWindowTests.swift`
  - Assert width controls are gone and Settings recenters each time it is shown.

---

### Task 1: Add Failing Split Layout Tests

**Files:**
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add ratio and dragging tests**

Append these tests above the existing helper methods in `MainWindowLayoutTests`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: FAIL because `MainWindowController(visibleFrame:settings:)` does not exist and fixed width constraints still drive split positions.

---

### Task 2: Implement Ratio-Based Split Layout and Maximized Windows

**Files:**
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Replace fixed width state with ratio state**

In `MainWindowController`, replace:

```swift
private var settings = SettingsStore.load()
private var filesWidthConstraint: NSLayoutConstraint?
private var outlineWidthConstraint: NSLayoutConstraint?
```

with:

```swift
private var settings: AppSettings
private var lastAppliedLayoutMode: LayoutMode?
private var isDeferringSplitRatioApplication = false

private enum SplitRatio {
    static let folderFiles: CGFloat = 0.17
    static let folderOutline: CGFloat = 0.14
    static let singleFileOutline: CGFloat = 0.16
}
```

- [ ] **Step 2: Add a testable initializer that maximizes to visible frame**

Replace the current `convenience init()` with:

```swift
convenience init(
    visibleFrame: NSRect? = NSScreen.main?.visibleFrame,
    settings: AppSettings = SettingsStore.load()
) {
    let frame = visibleFrame ?? NSRect(x: 0, y: 0, width: 1100, height: 760)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: min(frame.width, 1100), height: min(frame.height, 760)),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.setFrame(frame, display: false)
    self.init(window: window, settings: settings)
    window.title = "mdreview"
    buildLayout()
}

init(window: NSWindow, settings: AppSettings = SettingsStore.load()) {
    self.settings = settings
    super.init(window: window)
}

required init?(coder: NSCoder) {
    self.settings = SettingsStore.load()
    super.init(coder: coder)
}
```

Keep `windowDidLoad()` unchanged.

- [ ] **Step 3: Remove fixed width constraints from layout construction**

In `buildLayout()`, delete this block:

```swift
filesWidthConstraint = sidebar.filesView.widthAnchor.constraint(equalToConstant: CGFloat(settings.filesWidth))
outlineWidthConstraint = sidebar.outlineView.widthAnchor.constraint(equalToConstant: CGFloat(settings.outlineWidth))
filesWidthConstraint?.priority = .defaultHigh
outlineWidthConstraint?.priority = .defaultHigh
let rendererMinimumWidth = renderer.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
rendererMinimumWidth.priority = .defaultHigh
NSLayoutConstraint.activate([filesWidthConstraint, outlineWidthConstraint, rendererMinimumWidth].compactMap { $0 })
```

Do not add replacement min-width or max-width constraints.

- [ ] **Step 4: Replace sidebar width application with one-shot ratio application**

Delete `applySidebarWidths(layoutMode:)` and add:

```swift
private func applyDefaultSplitRatioIfNeeded(for layoutMode: LayoutMode, force: Bool) {
    guard force else { return }
    window?.contentView?.layoutSubtreeIfNeeded()
    splitView.layoutSubtreeIfNeeded()

    let totalWidth = splitView.bounds.width
    guard totalWidth > 0 else {
        guard !isDeferringSplitRatioApplication else { return }
        isDeferringSplitRatioApplication = true
        DispatchQueue.main.async { [weak self] in
            self?.isDeferringSplitRatioApplication = false
            self?.applyDefaultSplitRatioIfNeeded(for: layoutMode, force: true)
        }
        return
    }

    switch layoutMode {
    case .filesOutlineAndDocument:
        sidebar.filesView.isHidden = false
        splitView.setPosition(totalWidth * SplitRatio.folderFiles, ofDividerAt: 0)
        splitView.setPosition(totalWidth * (SplitRatio.folderFiles + SplitRatio.folderOutline), ofDividerAt: 1)
    case .outlineAndDocument:
        sidebar.filesView.isHidden = true
        splitView.setPosition(0, ofDividerAt: 0)
        splitView.setPosition(totalWidth * SplitRatio.singleFileOutline, ofDividerAt: 1)
    }

    splitView.layoutSubtreeIfNeeded()
}
```

- [ ] **Step 5: Apply ratios only for new windows and layout-mode changes**

In `apply(windowModel:)`, replace:

```swift
sidebar.apply(layoutMode: windowModel.layoutMode)
applySidebarWidths(layoutMode: windowModel.layoutMode)
```

with:

```swift
let shouldApplyDefaultRatio = lastAppliedLayoutMode != windowModel.layoutMode
lastAppliedLayoutMode = windowModel.layoutMode
sidebar.apply(layoutMode: windowModel.layoutMode)
applyDefaultSplitRatioIfNeeded(for: windowModel.layoutMode, force: shouldApplyDefaultRatio)
```

Do not call `applyDefaultSplitRatioIfNeeded` from `reloadDocument()` or from resize handling.

- [ ] **Step 6: Run focused native layout tests**

Run:

```bash
xcrun swift test --package-path native --filter MainWindowLayoutTests
```

Expected: PASS for all `MainWindowLayoutTests`.

- [ ] **Step 7: Commit**

```bash
git add native/Sources/MdreviewApp/MainWindowController.swift native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "fix: use draggable ratio split layout"
```

---

### Task 3: Center Settings Window and Remove Active Width Controls

**Files:**
- Create: `native/Tests/MdreviewAppTests/SettingsWindowTests.swift`
- Modify: `native/Sources/MdreviewApp/SettingsWindowController.swift`
- Modify: `native/Sources/MdreviewApp/AppDelegate.swift`

- [ ] **Step 1: Add failing Settings window tests**

Create `native/Tests/MdreviewAppTests/SettingsWindowTests.swift`:

```swift
import AppKit
import XCTest
@testable import MdreviewApp
@testable import MdreviewCore

@MainActor
final class SettingsWindowTests: XCTestCase {
    func testSettingsWindowDoesNotShowSidebarWidthControls() {
        let controller = SettingsWindowController(settings: .defaults)
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let labels = findSubviews(ofType: NSTextField.self, in: controller.window?.contentView).map(\.stringValue)
        XCTAssertFalse(labels.contains("文件栏默认宽度"))
        XCTAssertFalse(labels.contains("大纲栏默认宽度"))
    }

    func testShowCenteredRecentersEveryTimeRelativeToParentWindow() {
        let controller = SettingsWindowController(settings: .defaults)
        defer { controller.window?.close() }

        let parent = NSWindow(
            contentRect: NSRect(x: 100, y: 120, width: 900, height: 700),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        defer { parent.close() }

        controller.showCentered(relativeTo: parent)
        XCTAssertEqual(controller.window?.frame.midX ?? 0, parent.frame.midX, accuracy: 1)
        XCTAssertEqual(controller.window?.frame.midY ?? 0, parent.frame.midY, accuracy: 1)

        controller.window?.setFrameOrigin(NSPoint(x: 0, y: 0))
        parent.setFrame(NSRect(x: 300, y: 260, width: 1000, height: 760), display: false)

        controller.showCentered(relativeTo: parent)
        XCTAssertEqual(controller.window?.frame.midX ?? 0, parent.frame.midX, accuracy: 1)
        XCTAssertEqual(controller.window?.frame.midY ?? 0, parent.frame.midY, accuracy: 1)
    }

    func testSavingSettingsPreservesExistingSidebarWidths() throws {
        var savedSettings: AppSettings?
        let initial = AppSettings(
            openFoldersInNewWindow: false,
            autoRefreshSingleFile: true,
            restoreLastWindow: false,
            filesWidth: 333,
            outlineWidth: 222,
            showFiles: true,
            showOutline: true
        )
        let controller = SettingsWindowController(settings: initial) { settings in
            savedSettings = settings
        }
        defer { controller.window?.close() }
        controller.showWindow(nil)

        let autoRefresh = try XCTUnwrap(findSubviews(ofType: NSButton.self, in: controller.window?.contentView).first {
            $0.title == "自动刷新单文件"
        })
        autoRefresh.performClick(nil)

        XCTAssertEqual(savedSettings?.filesWidth, 333)
        XCTAssertEqual(savedSettings?.outlineWidth, 222)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcrun swift test --package-path native --filter SettingsWindowTests
```

Expected: FAIL because `SettingsWindowController(settings:saveSettings:)` and `showCentered(relativeTo:)` do not exist, and width controls are still visible.

- [ ] **Step 3: Make SettingsWindowController testable and remove width UI**

In `SettingsWindowController`, replace the singleton/private initializer area:

```swift
static let shared = SettingsWindowController()

private var settings = SettingsStore.load()
private let openFolders = NSButton(checkboxWithTitle: "打开文件夹时默认新建窗口", target: nil, action: nil)
private let autoRefresh = NSButton(checkboxWithTitle: "自动刷新单文件", target: nil, action: nil)
private let restoreWindow = NSButton(checkboxWithTitle: "启动时恢复上次窗口", target: nil, action: nil)
private let showFiles = NSButton(checkboxWithTitle: "显示文件栏", target: nil, action: nil)
private let showOutline = NSButton(checkboxWithTitle: "显示大纲栏", target: nil, action: nil)
private let filesWidth = NSTextField()
private let outlineWidth = NSTextField()

private init() {
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    super.init(window: window)
    window.title = "设置"
    buildContent()
    apply(settings)
}
```

with:

```swift
static let shared = SettingsWindowController()

private var settings: AppSettings
private let saveSettings: (AppSettings) -> Void
private let openFolders = NSButton(checkboxWithTitle: "打开文件夹时默认新建窗口", target: nil, action: nil)
private let autoRefresh = NSButton(checkboxWithTitle: "自动刷新单文件", target: nil, action: nil)
private let restoreWindow = NSButton(checkboxWithTitle: "启动时恢复上次窗口", target: nil, action: nil)
private let showFiles = NSButton(checkboxWithTitle: "显示文件栏", target: nil, action: nil)
private let showOutline = NSButton(checkboxWithTitle: "显示大纲栏", target: nil, action: nil)

init(
    settings: AppSettings = SettingsStore.load(),
    saveSettings: @escaping (AppSettings) -> Void = { SettingsStore.save($0) }
) {
    self.settings = settings
    self.saveSettings = saveSettings
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    super.init(window: window)
    window.title = "设置"
    buildContent()
    apply(settings)
}
```

In `buildContent()`, replace the arranged subview list:

```swift
[openFolders, autoRefresh, restoreWindow, widthRow(label: "文件栏默认宽度", field: filesWidth), widthRow(label: "大纲栏默认宽度", field: outlineWidth), showFiles, showOutline].forEach {
    stack.addArrangedSubview($0)
}
```

with:

```swift
[openFolders, autoRefresh, restoreWindow, showFiles, showOutline].forEach {
    stack.addArrangedSubview($0)
}
```

Delete this block:

```swift
[filesWidth, outlineWidth].forEach {
    $0.target = self
    $0.action = #selector(save)
    $0.widthAnchor.constraint(equalToConstant: 80).isActive = true
}
```

Delete `widthRow(label:field:)`.

In `apply(_:)`, delete:

```swift
filesWidth.stringValue = String(Int(settings.filesWidth))
outlineWidth.stringValue = String(Int(settings.outlineWidth))
```

In `save()`, replace:

```swift
filesWidth: Double(filesWidth.stringValue) ?? AppSettings.defaults.filesWidth,
outlineWidth: Double(outlineWidth.stringValue) ?? AppSettings.defaults.outlineWidth,
```

with:

```swift
filesWidth: settings.filesWidth,
outlineWidth: settings.outlineWidth,
```

Also in `save()`, replace:

```swift
SettingsStore.save(settings)
```

with:

```swift
saveSettings(settings)
```

- [ ] **Step 4: Add centered show behavior**

Add this method to `SettingsWindowController`:

```swift
func showCentered(relativeTo parentWindow: NSWindow?) {
    if let parentWindow, let window {
        let parentFrame = parentWindow.frame
        let windowFrame = window.frame
        let origin = NSPoint(
            x: parentFrame.midX - windowFrame.width / 2,
            y: parentFrame.midY - windowFrame.height / 2
        )
        window.setFrameOrigin(origin)
    } else {
        window?.center()
    }
    showWindow(nil)
}
```

- [ ] **Step 5: Route the Settings menu through centered show**

In `AppDelegate.openSettings()`, replace:

```swift
SettingsWindowController.shared.showWindow(nil)
```

with:

```swift
SettingsWindowController.shared.showCentered(relativeTo: activeController()?.window)
```

- [ ] **Step 6: Run focused Settings tests**

Run:

```bash
xcrun swift test --package-path native --filter SettingsWindowTests
```

Expected: PASS.

- [ ] **Step 7: Run existing settings persistence tests**

Run:

```bash
xcrun swift test --package-path native --filter SettingsTests
```

Expected: PASS; `AppSettings` still stores old width values for compatibility.

- [ ] **Step 8: Commit**

```bash
git add native/Sources/MdreviewApp/SettingsWindowController.swift native/Sources/MdreviewApp/AppDelegate.swift native/Tests/MdreviewAppTests/SettingsWindowTests.swift
git commit -m "fix: center settings and remove width controls"
```

---

### Task 4: Add Chinese Quit Menu Item

**Files:**
- Modify: `native/Sources/MdreviewCore/MenuText.swift`
- Modify: `native/Tests/MdreviewCoreTests/MenuTextTests.swift`
- Modify: `native/Sources/MdreviewApp/AppDelegate.swift`
- Create: `native/Tests/MdreviewAppTests/AppMenuTests.swift`

- [ ] **Step 1: Add failing menu text assertion**

In `native/Tests/MdreviewCoreTests/MenuTextTests.swift`, add:

```swift
XCTAssertEqual(MenuText.quit, "退出 mdreview")
```

inside `testChineseMenuTitles()`.

- [ ] **Step 2: Add failing app menu structure test**

Create `native/Tests/MdreviewAppTests/AppMenuTests.swift`:

```swift
import AppKit
import XCTest
@testable import MdreviewApp
@testable import MdreviewCore

@MainActor
final class AppMenuTests: XCTestCase {
    func testAppMenuContainsSettingsSeparatorAndQuit() throws {
        let delegate = AppDelegate()
        let menu = delegate.buildMenu()
        let appMenu = try XCTUnwrap(menu.item(at: 0)?.submenu)

        XCTAssertEqual(appMenu.item(at: 0)?.title, MenuText.settings)
        XCTAssertTrue(appMenu.item(at: 1)?.isSeparatorItem ?? false)

        let quit = try XCTUnwrap(appMenu.item(at: 2))
        XCTAssertEqual(quit.title, MenuText.quit)
        XCTAssertEqual(quit.keyEquivalent, "q")
        XCTAssertEqual(quit.action, #selector(NSApplication.terminate(_:)))
        XCTAssertTrue(quit.target === NSApp)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
xcrun swift test --package-path native --filter MenuTextTests
xcrun swift test --package-path native --filter AppMenuTests
```

Expected: FAIL because `MenuText.quit` does not exist and `AppDelegate.buildMenu()` is private with no Quit item.

- [ ] **Step 4: Add localized Quit text**

In `native/Sources/MdreviewCore/MenuText.swift`, add:

```swift
public static let quit = "退出 mdreview"
```

below `settings`.

- [ ] **Step 5: Expose menu construction to tests and add Quit**

In `AppDelegate`, change:

```swift
private func buildMenu() -> NSMenu {
```

to:

```swift
func buildMenu() -> NSMenu {
```

In `buildMenu()`, after the Settings item:

```swift
appMenu.addItem(menuItem(title: MenuText.settings, action: #selector(openSettings), keyEquivalent: ","))
```

add:

```swift
appMenu.addItem(.separator())
let quitItem = NSMenuItem(title: MenuText.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
quitItem.target = NSApp
appMenu.addItem(quitItem)
```

- [ ] **Step 6: Run focused menu tests**

Run:

```bash
xcrun swift test --package-path native --filter MenuTextTests
xcrun swift test --package-path native --filter AppMenuTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add native/Sources/MdreviewCore/MenuText.swift native/Tests/MdreviewCoreTests/MenuTextTests.swift native/Sources/MdreviewApp/AppDelegate.swift native/Tests/MdreviewAppTests/AppMenuTests.swift
git commit -m "fix: add quit menu item"
```

---

### Task 5: Full Verification and Install

**Files:**
- No planned source edits.

- [ ] **Step 1: Run all native tests**

Run:

```bash
xcrun swift test --package-path native
```

Expected: PASS for `MdreviewAppTests`, `MdreviewCoreTests`, and `MdreviewIPCTests`.

- [ ] **Step 2: Run full project verification**

Run:

```bash
npm run test:all
```

Expected: PASS for typecheck, web/node tests, and native tests.

- [ ] **Step 3: Build and install local app**

Run:

```bash
npm run install:local
```

Expected: App installed at `/Users/kuchen/Applications/mdreview.app` and `mdreview` command registered.

- [ ] **Step 4: Manual verification for folder mode**

Run:

```bash
osascript -e 'quit app "mdreview"' || true
mdreview docs/superpowers --new-window
```

Expected:

- The main window opens maximized to the usable screen area.
- It is not macOS full screen; the normal title bar remains.
- Files, Outline, and document columns start around `17% / 14% / 69%`.
- Both split dividers can be dragged.
- After dragging, opening another file in the same folder keeps the current divider positions.

- [ ] **Step 5: Manual verification for single-file mode**

Run:

```bash
mdreview README.md --new-window
```

Expected:

- The file list is hidden.
- Outline and document start around `16% / 84%`.
- The outline/document divider can be dragged.

- [ ] **Step 6: Manual verification for Settings and Quit**

In the running app:

- Choose `mdreview > 设置...`.
- Move the Settings window away from center.
- Close it.
- Choose `mdreview > 设置...` again.
- Confirm it recenters relative to the main window.
- Confirm no `文件栏默认宽度` or `大纲栏默认宽度` controls are visible.
- Choose `mdreview > 退出 mdreview`.

Expected: the app terminates.

- [ ] **Step 7: Final status check**

Run:

```bash
git status --short
git log --oneline -5
```

Expected: only intentional changes are present, with commits for split layout, settings, and quit menu.
