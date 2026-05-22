# mdreview Reader UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the native mdreview window into a clean Typora / Reader style Markdown previewer with text navigation, low-chrome tabs, scoped native renderer CSS, and verified `Cmd+W` behavior.

**Architecture:** Keep the existing AppKit shell, split view, native sidebar, app reducer, and `WKWebView` renderer. Native presentation changes live in small AppKit controls used by `SidebarController` and `DocumentTabBar`; Markdown reading typography is scoped to the file-loaded `RendererApp` root so the old browser preview keeps its current app shell.

**Tech Stack:** Swift 6 / AppKit / XCTest, React 19 / TypeScript / Vite / Vitest / Testing Library, WKWebView, CSS.

---

## Current Workspace Baseline

The current working tree contains uncommitted functional fixes from the previous debugging pass:

- `native/Sources/MdreviewApp/AppDelegate.swift`
- `native/Sources/MdreviewApp/MainWindowController.swift`
- `native/Sources/MdreviewApp/SidebarController.swift`
- `native/Sources/MdreviewCore/AppReducer.swift`
- `native/Sources/MdreviewCore/MarkdownOutline.swift`
- `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
- `native/Tests/MdreviewCoreTests/AppReducerTests.swift`
- `native/Tests/MdreviewCoreTests/MarkdownOutlineTests.swift`

Do not revert these files. Task 1 verifies and commits that baseline before the Reader UI work starts.

This plan assumes execution in the current workspace. Do not create or switch to a git worktree unless the user explicitly changes that instruction.

## File Structure

- Create `native/Sources/MdreviewApp/SidebarRowButton.swift`
  - Owns text-navigation row rendering for Files and Outline.
  - Preserves `NSButton` semantics, target/action, keyboard activation, focusability, and accessibility label.
  - Handles active and hover visual states.

- Modify `native/Sources/MdreviewApp/SidebarController.swift`
  - Replaces rounded `NSButton` rows with `SidebarRowButton`.
  - Tracks clicked outline active state.
  - Clears outline active state on re-render.
  - Keeps Files active state derived from active file path.

- Create `native/Sources/MdreviewApp/DocumentTabButton.swift`
  - Owns low-chrome text tab rendering.
  - Keeps `NSButton` semantics.
  - Uses text color and underline to show active tab.

- Modify `native/Sources/MdreviewApp/DocumentTabBar.swift`
  - Replaces rounded tab buttons with `DocumentTabButton`.

- Modify `native/Sources/MdreviewApp/MainWindowController.swift`
  - Keeps existing split view and renderer flow.
  - No layout-model rewrite.

- Modify `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
  - Adds native UI assertions for text rows, active state, accessibility, and text tabs.

- Modify `src/web/renderer/RendererApp.tsx`
  - Adds a `.native-reader` scoped root for the `WKWebView` renderer.

- Modify `src/web/styles.css`
  - Adds `.native-reader` scoped Reader typography.
  - Leaves old browser preview shell selectors intact.

- Modify `tests/web/renderer/RendererApp.test.tsx`
  - Verifies the native renderer root class.

- Modify `tests/web/App.test.tsx`
  - Verifies browser preview does not use the native renderer root class.

- Create `tests/web/reader-style.test.ts`
  - Verifies Reader CSS is scoped to `.native-reader`.

---

### Task 1: Commit Existing Functional Baseline

**Files:**
- Verify: `native/Sources/MdreviewApp/AppDelegate.swift`
- Verify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Verify: `native/Sources/MdreviewApp/SidebarController.swift`
- Verify: `native/Sources/MdreviewCore/AppReducer.swift`
- Verify: `native/Sources/MdreviewCore/MarkdownOutline.swift`
- Verify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`
- Verify: `native/Tests/MdreviewCoreTests/AppReducerTests.swift`
- Verify: `native/Tests/MdreviewCoreTests/MarkdownOutlineTests.swift`

- [ ] **Step 1: Confirm the expected baseline diff**

Run:

```bash
git status --short
```

Expected: the native files listed in the "Current Workspace Baseline" section are modified or untracked. `docs/superpowers/plans/2026-05-22-mdreview-reader-ui.md` will also be present when executing from this plan commit.

- [ ] **Step 2: Verify native outline rendering baseline**

Run:

```bash
npm run test:native -- --filter MainWindowLayoutTests/testSingleFileShowsNativeOutlineHeadings
```

Expected: PASS.

- [ ] **Step 3: Verify tab closing baseline**

Run:

```bash
npm run test:native -- --filter AppReducerTests/testClosingLastActiveTabRemovesWindow
npm run test:native -- --filter AppReducerTests/testClosingActiveTabKeepsWindowWhenAnotherTabRemains
```

Expected: PASS for both filters.

- [ ] **Step 4: Commit the baseline fixes**

Run:

```bash
git add \
  native/Sources/MdreviewApp/AppDelegate.swift \
  native/Sources/MdreviewApp/MainWindowController.swift \
  native/Sources/MdreviewApp/SidebarController.swift \
  native/Sources/MdreviewCore/AppReducer.swift \
  native/Sources/MdreviewCore/MarkdownOutline.swift \
  native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift \
  native/Tests/MdreviewCoreTests/AppReducerTests.swift \
  native/Tests/MdreviewCoreTests/MarkdownOutlineTests.swift
git commit -m "fix: stabilize native outline and tab closing"
```

Expected: a commit containing only the existing baseline fixes. If `git commit` reports there is nothing to commit for these paths, run `git status --short` and continue only if the baseline files are already clean.

---

### Task 2: Add Failing Native Tests for Reader Sidebar Rows

**Files:**
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add sidebar text-navigation tests**

Append these tests inside `MainWindowLayoutTests` before the helper methods:

```swift
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
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
npm run test:native -- --filter MainWindowLayoutTests/testSingleFileOutlineUsesAccessibleTextNavigationRows
npm run test:native -- --filter MainWindowLayoutTests/testOutlineSelectionAppliesActiveStateAndRerenderClearsIt
```

Expected: FAIL because `SidebarRowButton` does not exist.

---

### Task 3: Implement Sidebar Text Navigation Rows

**Files:**
- Create: `native/Sources/MdreviewApp/SidebarRowButton.swift`
- Modify: `native/Sources/MdreviewApp/SidebarController.swift`
- Test: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Create `SidebarRowButton`**

Create `native/Sources/MdreviewApp/SidebarRowButton.swift`:

```swift
import AppKit

@MainActor
final class SidebarRowButton: NSButton {
    enum RowKind {
        case file
        case outline
    }

    let depth: Int
    private let kind: RowKind
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    var isActive: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, identifier: String, depth: Int, isActive: Bool, kind: RowKind, target: AnyObject?, action: Selector) {
        self.depth = depth
        self.isActive = isActive
        self.kind = kind
        super.init(frame: .zero)
        self.title = title
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        self.target = target
        self.action = action
        setButtonType(.momentaryChange)
        isBordered = false
        bezelStyle = .regularSquare
        alignment = .left
        lineBreakMode = .byTruncatingMiddle
        focusRingType = .default
        setAccessibilityLabel(title)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: max(96, base.width + CGFloat(depth * 14) + 24), height: 24)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let next = NSTrackingArea(rect: bounds, options: options, owner: self)
        addTrackingArea(next)
        trackingArea = next
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    private func updateAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.backgroundColor = backgroundColor.cgColor
        contentTintColor = textColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: fontForRow,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private var backgroundColor: NSColor {
        if isActive {
            return NSColor.separatorColor.withAlphaComponent(0.28)
        }
        if isHovered {
            return NSColor.separatorColor.withAlphaComponent(0.16)
        }
        return .clear
    }

    private var textColor: NSColor {
        if isActive {
            return .labelColor
        }
        return kind == .outline && depth > 1 ? .tertiaryLabelColor : .secondaryLabelColor
    }

    private var fontForRow: NSFont {
        if kind == .outline && depth == 0 {
            return .systemFont(ofSize: 13, weight: .medium)
        }
        return .systemFont(ofSize: 13, weight: .regular)
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingMiddle
        style.firstLineHeadIndent = CGFloat(depth * 14)
        style.headIndent = CGFloat(depth * 14)
        return style
    }
}
```

- [ ] **Step 2: Replace sidebar buttons with `SidebarRowButton`**

Modify `native/Sources/MdreviewApp/SidebarController.swift` so the class stores outline items and active heading state:

```swift
private var outlineItems = [NativeOutlineItem]()
private var activeHeadingID: String?
```

Replace `renderOutline(_:)`, `selectHeading(_:)`, and the file-row creation logic with this implementation:

```swift
func renderOutline(_ items: [NativeOutlineItem]) {
    outlineItems = items
    activeHeadingID = nil
    reloadOutlineRows()
}

private func reloadOutlineRows() {
    clear(outlineStack)
    if outlineItems.isEmpty {
        outlineStack.addArrangedSubview(emptyLabel("没有大纲"))
    } else {
        for item in outlineItems {
            let row = SidebarRowButton(
                title: item.text,
                identifier: item.id,
                depth: max(0, item.depth - 1),
                isActive: item.id == activeHeadingID,
                kind: .outline,
                target: self,
                action: #selector(selectHeading(_:))
            )
            outlineStack.addArrangedSubview(row)
        }
    }
    outlineView.needsLayout = true
}

private func addFiles(_ nodes: [MarkdownNode], depth: Int, activePath: String?) {
    for node in nodes {
        if node.type == .directory {
            let label = emptyLabel(node.name)
            label.textColor = .tertiaryLabelColor
            filesStack.addArrangedSubview(label)
            addFiles(node.children, depth: depth + 1, activePath: activePath)
        } else {
            let row = SidebarRowButton(
                title: node.name,
                identifier: node.path,
                depth: depth,
                isActive: node.path == activePath,
                kind: .file,
                target: self,
                action: #selector(selectFile(_:))
            )
            filesStack.addArrangedSubview(row)
        }
    }
}

@objc private func selectFile(_ sender: SidebarRowButton) {
    guard let path = sender.identifier?.rawValue else { return }
    onSelectFile?(path)
}

@objc private func selectHeading(_ sender: SidebarRowButton) {
    guard let id = sender.identifier?.rawValue else { return }
    activeHeadingID = id
    reloadOutlineRows()
    onSelectHeading?(id)
}

private func emptyLabel(_ title: String) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.font = .systemFont(ofSize: 12)
    label.textColor = .tertiaryLabelColor
    return label
}
```

In `renderFiles(nodes:activePath:)`, replace the empty-state label with:

```swift
filesStack.addArrangedSubview(emptyLabel("没有 Markdown 文件"))
```

Keep `SidebarStackView` and `SidebarScrollView` from the baseline fix.

- [ ] **Step 3: Run focused native tests**

Run:

```bash
npm run test:native -- --filter MainWindowLayoutTests/testSingleFileOutlineUsesAccessibleTextNavigationRows
npm run test:native -- --filter MainWindowLayoutTests/testOutlineSelectionAppliesActiveStateAndRerenderClearsIt
npm run test:native -- --filter MainWindowLayoutTests/testSingleFileShowsNativeOutlineHeadings
```

Expected: PASS for all three filters.

- [ ] **Step 4: Commit sidebar work**

Run:

```bash
git add \
  native/Sources/MdreviewApp/SidebarRowButton.swift \
  native/Sources/MdreviewApp/SidebarController.swift \
  native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "style: use text navigation sidebar rows"
```

Expected: one commit containing sidebar row styling and tests.

---

### Task 4: Add Low-Chrome Document Tabs

**Files:**
- Create: `native/Sources/MdreviewApp/DocumentTabButton.swift`
- Modify: `native/Sources/MdreviewApp/DocumentTabBar.swift`
- Modify: `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`

- [ ] **Step 1: Add failing tab bar test**

Append this test inside `MainWindowLayoutTests` before helper methods:

```swift
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
```

- [ ] **Step 2: Run test and verify failure**

Run:

```bash
npm run test:native -- --filter MainWindowLayoutTests/testDocumentTabsUseLowChromeTextButtons
```

Expected: FAIL because `DocumentTabButton` does not exist.

- [ ] **Step 3: Create `DocumentTabButton`**

Create `native/Sources/MdreviewApp/DocumentTabButton.swift`:

```swift
import AppKit

@MainActor
final class DocumentTabButton: NSButton {
    var isActive: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, identifier: String, isActive: Bool, target: AnyObject?, action: Selector) {
        self.isActive = isActive
        super.init(frame: .zero)
        self.title = title
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        self.target = target
        self.action = action
        setButtonType(.momentaryChange)
        isBordered = false
        bezelStyle = .regularSquare
        alignment = .center
        lineBreakMode = .byTruncatingMiddle
        focusRingType = .default
        setAccessibilityLabel(title)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: max(72, base.width + 18), height: 30)
    }

    private func updateAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingMiddle
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: isActive ? .medium : .regular),
            .foregroundColor: isActive ? NSColor.labelColor : NSColor.secondaryLabelColor,
            .paragraphStyle: style
        ]
        if isActive {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.underlineColor] = NSColor.separatorColor
        }
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }
}
```

- [ ] **Step 4: Use `DocumentTabButton` in `DocumentTabBar`**

Replace the tab button creation loop in `native/Sources/MdreviewApp/DocumentTabBar.swift` with:

```swift
for tab in tabs {
    let button = DocumentTabButton(
        title: tab.title,
        identifier: tab.id.uuidString,
        isActive: tab.id == activeTabID,
        target: self,
        action: #selector(selectTab(_:))
    )
    view.addArrangedSubview(button)
}
```

Change the selector signature to:

```swift
@objc private func selectTab(_ sender: DocumentTabButton) {
    guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
    onSelectTab?(id)
}
```

- [ ] **Step 5: Run tab tests**

Run:

```bash
npm run test:native -- --filter MainWindowLayoutTests/testDocumentTabsUseLowChromeTextButtons
npm run test:native -- --filter MainWindowLayoutTests/testSplitViewFillsDocumentAreaAndUsesSideBySideColumns
```

Expected: PASS for both filters.

- [ ] **Step 6: Commit tab bar work**

Run:

```bash
git add \
  native/Sources/MdreviewApp/DocumentTabButton.swift \
  native/Sources/MdreviewApp/DocumentTabBar.swift \
  native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "style: reduce document tab chrome"
```

Expected: one commit containing tab bar styling and tests.

---

### Task 5: Scope Native Renderer Root

**Files:**
- Modify: `src/web/renderer/RendererApp.tsx`
- Modify: `tests/web/renderer/RendererApp.test.tsx`
- Modify: `tests/web/App.test.tsx`

- [ ] **Step 1: Add failing renderer root test**

Append this test to `tests/web/renderer/RendererApp.test.tsx`:

```tsx
it("scopes the WKWebView renderer with the native reader root class", async () => {
  window.__mdreviewPendingDocument = {
    type: "renderDocument",
    path: "/tmp/README.md",
    name: "README.md",
    content: "# Hello"
  };

  const { container } = render(<RendererApp />);

  expect(await screen.findByRole("heading", { name: "Hello" })).toBeInTheDocument();
  expect(container.querySelector(".native-reader")).toBeInTheDocument();
  expect(container.querySelector(".native-reader .markdown-body")).toBeInTheDocument();
});
```

- [ ] **Step 2: Add browser preview isolation test**

Append this test to `tests/web/App.test.tsx`:

```tsx
it("does not apply the native reader root class to browser preview", async () => {
  window.history.pushState(null, "", "/#token=test-token");
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string) => {
      if (url.endsWith("/api/session")) {
        return Response.json({ mode: "file", rootName: "README.md", defaultDocument: "README.md" });
      }
      return Response.json({ path: "README.md", name: "README.md", mtime: 1, content: "# Hello" });
    })
  );

  const { container } = render(<App />);
  await waitFor(() => expect(screen.getByText("README.md")).toBeInTheDocument());
  expect(container.querySelector(".native-reader")).toBeNull();
});
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
npm test -- tests/web/renderer/RendererApp.test.tsx tests/web/App.test.tsx
```

Expected: `RendererApp` native root test FAILS because `.native-reader` is missing; the browser preview isolation test PASSES or remains neutral.

- [ ] **Step 4: Add `.native-reader` root in `RendererApp`**

Replace the return branches in `src/web/renderer/RendererApp.tsx` with:

```tsx
if (!document) {
  return <main className="native-reader renderer-empty">等待文档...</main>;
}

return (
  <main className="native-reader">
    <article className="markdown-body">
      <MarkdownView content={rewriteMarkdownResources(document.content)} onOutline={onOutline} />
    </article>
  </main>
);
```

- [ ] **Step 5: Run renderer and browser preview tests**

Run:

```bash
npm test -- tests/web/renderer/RendererApp.test.tsx tests/web/App.test.tsx
```

Expected: PASS.

- [ ] **Step 6: Commit renderer root work**

Run:

```bash
git add \
  src/web/renderer/RendererApp.tsx \
  tests/web/renderer/RendererApp.test.tsx \
  tests/web/App.test.tsx
git commit -m "style: scope native reader renderer"
```

Expected: one commit containing native renderer root scoping and tests.

---

### Task 6: Add Scoped Reader Typography CSS

**Files:**
- Create: `tests/web/reader-style.test.ts`
- Modify: `src/web/styles.css`

- [ ] **Step 1: Add CSS scoping test**

Create `tests/web/reader-style.test.ts`:

```ts
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const css = readFileSync(new URL("../../src/web/styles.css", import.meta.url), "utf8");

describe("native reader stylesheet", () => {
  it("scopes long-form reader typography to the native renderer root", () => {
    expect(css).toContain(".native-reader .markdown-body");
    expect(css).toContain("max-width: 620px");
    expect(css).toContain("padding: 56px 40px 92px");
    expect(css).not.toMatch(/^\\.markdown-body\\s*{[^}]*max-width:\\s*620px/ms);
  });
});
```

- [ ] **Step 2: Run test and verify failure**

Run:

```bash
npm test -- tests/web/reader-style.test.ts
```

Expected: FAIL because Reader CSS is not scoped to `.native-reader`.

- [ ] **Step 3: Append native Reader CSS**

Append this block to `src/web/styles.css`:

```css
.native-reader {
  min-height: 100vh;
  background: #ffffff;
  color: #24292f;
  font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

.native-reader.renderer-empty {
  display: grid;
  place-items: center;
  color: #8a8f98;
  font-size: 13px;
}

.native-reader .markdown-body {
  box-sizing: border-box;
  max-width: 620px;
  margin: 0 auto;
  padding: 56px 40px 92px;
  font-size: 15px;
  line-height: 1.86;
  color: #30363d;
}

.native-reader .markdown-body h1,
.native-reader .markdown-body h2,
.native-reader .markdown-body h3,
.native-reader .markdown-body h4,
.native-reader .markdown-body h5,
.native-reader .markdown-body h6 {
  color: #1f2328;
  letter-spacing: 0;
  line-height: 1.18;
}

.native-reader .markdown-body h1 {
  margin: 0 0 28px;
  font-size: 34px;
  font-weight: 700;
}

.native-reader .markdown-body h2 {
  margin: 42px 0 16px;
  font-size: 24px;
  font-weight: 650;
}

.native-reader .markdown-body h3 {
  margin: 32px 0 12px;
  font-size: 19px;
  font-weight: 650;
}

.native-reader .markdown-body p,
.native-reader .markdown-body ul,
.native-reader .markdown-body ol,
.native-reader .markdown-body blockquote,
.native-reader .markdown-body table {
  margin-top: 0;
  margin-bottom: 18px;
}

.native-reader .markdown-body a {
  color: #0969da;
  text-decoration-thickness: 1px;
  text-underline-offset: 3px;
}

.native-reader .markdown-body :not(pre) > code {
  border-radius: 4px;
  background: #f6f8fa;
  color: #24292f;
  padding: 0.12em 0.34em;
  font-size: 0.92em;
}

.native-reader .markdown-body pre {
  overflow: auto;
  border: 1px solid #d8dee4;
  border-radius: 9px;
  background: #fafafa;
  padding: 15px 17px;
  line-height: 1.65;
}

.native-reader .markdown-body pre code {
  background: transparent;
  padding: 0;
  font-size: 12px;
}

.native-reader .markdown-body blockquote {
  border-left: 3px solid #d8dee4;
  color: #57606a;
  padding-left: 14px;
}

.native-reader .markdown-body img,
.native-reader .markdown-body svg {
  max-width: 100%;
  height: auto;
}

.native-reader .markdown-body table {
  display: block;
  width: max-content;
  max-width: 100%;
  overflow-x: auto;
  border-collapse: collapse;
}
```

- [ ] **Step 4: Run focused web tests**

Run:

```bash
npm test -- tests/web/reader-style.test.ts tests/web/renderer/RendererApp.test.tsx tests/web/App.test.tsx tests/web/MarkdownView.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit Reader CSS work**

Run:

```bash
git add src/web/styles.css tests/web/reader-style.test.ts
git commit -m "style: add scoped reader typography"
```

Expected: one commit containing scoped Reader CSS and CSS scoping test.

---

### Task 7: Full Verification and Local App Install

**Files:**
- Verify: all changed files
- Package output: `native/dist/mdreview.app`
- Installed app: `/Users/kuchen/Applications/mdreview.app`

- [ ] **Step 1: Run full automated verification**

Run:

```bash
npm run test:all
```

Expected: typecheck, Vitest, and Swift tests all PASS.

- [ ] **Step 2: Build and install local app**

Run:

```bash
npm run install:local
```

Expected output includes:

```text
已安装 App：/Users/kuchen/Applications/mdreview.app
已注册命令：mdreview
```

- [ ] **Step 3: Open single-file mode with the installed command**

Run:

```bash
pkill -x mdreview-app || true
mdreview README.md
```

Expected: mdreview opens `README.md` in the native app. Single-file mode shows Outline + document, with no Files panel.

- [ ] **Step 4: Capture visual evidence**

Run:

```bash
screencapture -x /tmp/mdreview-reader-ui.png
```

Expected: screenshot shows:

- Sidebar rows look like text navigation, not rounded buttons.
- Document background is white.
- Markdown content is centered and narrow.
- Top document tabs are low chrome.

- [ ] **Step 5: Verify accessibility and row geometry with AX**

Run:

```bash
osascript -e 'tell application "System Events" to set frontmost of process "mdreview-app" to true' -e 'tell application "System Events" to tell process "mdreview-app" to return {name, role, position, size} of UI elements of window 1'
```

Expected: output includes clickable controls for outline rows with readable names such as `mdreview`, `使用`, and `开发`. Row heights should be near 24px. Use Accessibility Inspector if the AppleScript output is too coarse on this macOS version.

- [ ] **Step 6: Verify `Cmd+W` closes the last tab/app**

Run:

```bash
pgrep -fl mdreview-app
osascript -e 'tell application "System Events" to set frontmost of process "mdreview-app" to true' -e 'tell application "System Events" to keystroke "w" using command down'
sleep 1
pgrep -fl mdreview-app || true
```

Expected: the final `pgrep` prints no `mdreview-app` process when only one tab was open.

- [ ] **Step 7: Verify directory mode**

Run:

```bash
mdreview docs
```

Expected: mdreview opens directory mode with Files + Outline. Both navigation layers use the same quiet row style. The active file row matches the current document.

- [ ] **Step 8: Handle verification failures through the owning task**

If Task 7 exposes a CSS issue, return to Task 6, change `src/web/styles.css` or `tests/web/reader-style.test.ts`, rerun Task 6 Step 4, and commit with:

```bash
git add src/web/styles.css tests/web/reader-style.test.ts
git commit -m "fix: polish reader typography"
```

If Task 7 exposes a sidebar issue, return to Task 3, change `native/Sources/MdreviewApp/SidebarRowButton.swift`, `native/Sources/MdreviewApp/SidebarController.swift`, or `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`, rerun Task 3 Step 3, and commit with:

```bash
git add \
  native/Sources/MdreviewApp/SidebarRowButton.swift \
  native/Sources/MdreviewApp/SidebarController.swift \
  native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "fix: polish sidebar reader rows"
```

If Task 7 exposes a tab bar issue, return to Task 4, change `native/Sources/MdreviewApp/DocumentTabButton.swift`, `native/Sources/MdreviewApp/DocumentTabBar.swift`, or `native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift`, rerun Task 4 Step 5, and commit with:

```bash
git add \
  native/Sources/MdreviewApp/DocumentTabButton.swift \
  native/Sources/MdreviewApp/DocumentTabBar.swift \
  native/Tests/MdreviewAppTests/MainWindowLayoutTests.swift
git commit -m "fix: polish document tabs"
```

Expected: no extra commit is created when Task 7 passes without code changes.
