# mdreview Native App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert mdreview from a browser-tab previewer into a Typora-style macOS app with a Chinese UI, app-managed document tabs, WKWebView Markdown rendering, and a `mdreview <path>` CLI handoff.

**Architecture:** Add a Swift/AppKit native app built with SwiftPM so it can run with Command Line Tools. The native app owns windows, document tabs, workspace state, file reading, resource authorization, menus, settings, and a Unix domain socket IPC server. The existing TypeScript renderer is refactored into a bridge-driven WKWebView document renderer instead of a browser shell.

**Tech Stack:** Swift 6/AppKit/WebKit/Network, SwiftPM/XCTest, Node.js/TypeScript/Vite/React/Vitest, Unix domain sockets, `WKScriptMessageHandler`, `WKURLSchemeHandler`, npm build scripts.

---

## Scope Check

This is a cohesive migration, but it has multiple layers. The tasks are ordered so each layer becomes testable before the next one depends on it:

1. Swift package and pure native core.
2. CLI IPC handoff.
3. AppKit window/menu shell.
4. WKWebView renderer bridge and resource scheme.
5. Renderer refactor.
6. Workspace/tabs/sidebar behavior.
7. Watcher, settings, packaging, verification.

Do not start from UI. Build pure model and IPC tests first so the native shell has stable contracts to call.

## File Structure

- `native/Package.swift`: SwiftPM package with core library, CLI IPC helper, and AppKit executable.
- `native/Sources/MdreviewCore/OpenRequest.swift`: JSON IPC request/response contracts.
- `native/Sources/MdreviewCore/SocketLocation.swift`: socket path and stale socket cleanup policy.
- `native/Sources/MdreviewCore/PathValidation.swift`: file/directory validation and canonical realpath helpers.
- `native/Sources/MdreviewCore/MarkdownTree.swift`: Markdown file tree scanning and default document selection.
- `native/Sources/MdreviewCore/AppModel.swift`: window, workspace, tab, layout, and settings model.
- `native/Sources/MdreviewCore/AppReducer.swift`: pure routing logic for open-file/open-directory requests.
- `native/Sources/MdreviewCore/ResourceAuthorizer.swift`: `mdreview-resource://` containment checks.
- `native/Sources/MdreviewCore/SettingsStore.swift`: typed settings defaults and persistence keys.
- `native/Sources/MdreviewCore/FileWatcher.swift`: DispatchSource-based file watcher.
- `native/Sources/MdreviewIPC/SocketServer.swift`: app-side Unix socket server.
- `native/Sources/MdreviewApp/main.swift`: AppKit entry point.
- `native/Sources/MdreviewApp/AppDelegate.swift`: app lifecycle and menu setup.
- `native/Sources/MdreviewApp/MainWindowController.swift`: native window, split views, tab strip, and renderer controller.
- `native/Sources/MdreviewApp/DocumentTabBar.swift`: application-managed document tabs.
- `native/Sources/MdreviewApp/SidebarController.swift`: Files and Outline columns with resizable widths.
- `native/Sources/MdreviewApp/RendererViewController.swift`: WKWebView setup and native-renderer bridge.
- `native/Sources/MdreviewApp/ResourceSchemeHandler.swift`: `WKURLSchemeHandler` for local images/resources.
- `native/Sources/MdreviewApp/SettingsWindowController.swift`: Chinese settings UI.
- `native/Tests/MdreviewCoreTests/*.swift`: pure Swift unit tests.
- `native/Tests/MdreviewIPCTests/*.swift`: socket server/client tests.
- `scripts/package-macos-app.mjs`: builds `.app` bundle from SwiftPM output and Vite renderer assets.
- `src/cli/args.ts`: replace browser flags with app flags and Chinese help.
- `src/cli/native-client.ts`: Node Unix socket client and app launcher.
- `src/cli/index.ts`: CLI entry becomes native app handoff.
- `src/web/App.tsx`: keeps dev browser shell only.
- `src/web/renderer/RendererApp.tsx`: bridge-driven Markdown renderer mounted in WKWebView.
- `src/web/renderer/bridge.ts`: native bridge message types and fallback dev bridge.
- `src/web/renderer/resources.ts`: rewrite allowed relative resources to `mdreview-resource://`.
- `tests/cli/*.test.ts`: updated CLI parser and IPC client tests.
- `tests/web/renderer/*.test.tsx`: renderer bridge/resource tests.
- `README.md`: native app usage and development commands.

## Implementation Tasks

### Task 1: SwiftPM Native Package Scaffold

**Files:**
- Create: `native/Package.swift`
- Create: `native/Sources/MdreviewCore/OpenRequest.swift`
- Create: `native/Sources/MdreviewCore/SocketLocation.swift`
- Create: `native/Sources/MdreviewApp/main.swift`
- Create: `native/Tests/MdreviewCoreTests/OpenRequestTests.swift`
- Modify: `.gitignore`
- Modify: `package.json`

- [ ] **Step 1: Add failing Swift contract tests**

Create `native/Tests/MdreviewCoreTests/OpenRequestTests.swift`:

```swift
import Darwin
import XCTest
@testable import MdreviewCore

final class OpenRequestTests: XCTestCase {
    func testDecodesOpenFileRequest() throws {
        let json = #"{"kind":"openFile","path":"/tmp/README.md","newWindow":false}"#.data(using: .utf8)!
        let request = try JSONDecoder().decode(OpenRequest.self, from: json)
        XCTAssertEqual(request.kind, .openFile)
        XCTAssertEqual(request.path, "/tmp/README.md")
        XCTAssertEqual(request.newWindow, false)
    }

    func testEncodesAcceptedResponse() throws {
        let response = OpenResponse(accepted: true, action: .opened, message: "已打开")
        let data = try JSONEncoder().encode(response)
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains(#""accepted":true"#))
        XCTAssertTrue(text.contains(#""action":"opened""#))
    }

    func testSocketPathUsesCurrentUserTmpDirectory() {
        let path = SocketLocation.defaultPath()
        XCTAssertTrue(path.hasSuffix("mdreview-\(getuid()).sock"))
        XCTAssertTrue(path.contains("/"))
    }
}
```

- [ ] **Step 2: Run Swift tests and verify failure**

Run:

```bash
swift test --package-path native --filter OpenRequestTests
```

Expected:

```text
error: Could not find Package.swift
```

- [ ] **Step 3: Create Swift package and minimal contracts**

Create `native/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mdreview-native",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MdreviewCore", targets: ["MdreviewCore"]),
        .library(name: "MdreviewIPC", targets: ["MdreviewIPC"]),
        .executable(name: "mdreview-app", targets: ["MdreviewApp"])
    ],
    targets: [
        .target(name: "MdreviewCore"),
        .target(name: "MdreviewIPC", dependencies: ["MdreviewCore"]),
        .executableTarget(name: "MdreviewApp", dependencies: ["MdreviewCore", "MdreviewIPC"]),
        .testTarget(name: "MdreviewCoreTests", dependencies: ["MdreviewCore"]),
        .testTarget(name: "MdreviewIPCTests", dependencies: ["MdreviewCore", "MdreviewIPC"])
    ]
)
```

Create `native/Sources/MdreviewCore/OpenRequest.swift`:

```swift
import Foundation

public enum OpenRequestKind: String, Codable, Equatable {
    case openFile
    case openDirectory
}

public struct OpenRequest: Codable, Equatable {
    public let kind: OpenRequestKind
    public let path: String
    public let newWindow: Bool

    public init(kind: OpenRequestKind, path: String, newWindow: Bool) {
        self.kind = kind
        self.path = path
        self.newWindow = newWindow
    }
}

public enum OpenResponseAction: String, Codable, Equatable {
    case opened
    case focused
    case rejected
}

public struct OpenResponse: Codable, Equatable {
    public let accepted: Bool
    public let action: OpenResponseAction
    public let message: String

    public init(accepted: Bool, action: OpenResponseAction, message: String) {
        self.accepted = accepted
        self.action = action
        self.message = message
    }
}
```

Create `native/Sources/MdreviewCore/SocketLocation.swift`:

```swift
import Darwin
import Foundation

public enum SocketLocation {
    public static func defaultPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let tmp = environment["TMPDIR"] ?? NSTemporaryDirectory()
        let trimmed = tmp.hasSuffix("/") ? String(tmp.dropLast()) : tmp
        return "\(trimmed)/mdreview-\(getuid()).sock"
    }
}
```

Create `native/Sources/MdreviewApp/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.run()
```

- [ ] **Step 4: Add native scripts and ignore build outputs**

Modify `.gitignore`:

```gitignore
native/.build/
native/dist/
```

Modify `package.json` scripts:

```json
{
  "build:native": "swift build --package-path native",
  "test:native": "swift test --package-path native"
}
```

Preserve all existing scripts.

- [ ] **Step 5: Verify scaffold**

Run:

```bash
npm run test:native
npm run build:native
```

Expected:

```text
OpenRequestTests ... passed
Build complete
```

- [ ] **Step 6: Commit scaffold**

```bash
git add .gitignore package.json native
git commit -m "chore: scaffold native mac app package"
```

### Task 2: Native Filesystem and Resource Boundaries

**Files:**
- Create: `native/Sources/MdreviewCore/PathValidation.swift`
- Create: `native/Sources/MdreviewCore/MarkdownTree.swift`
- Create: `native/Sources/MdreviewCore/ResourceAuthorizer.swift`
- Create: `native/Tests/MdreviewCoreTests/FilesystemTests.swift`

- [ ] **Step 1: Write failing filesystem tests**

Create `native/Tests/MdreviewCoreTests/FilesystemTests.swift`:

```swift
import Foundation
import XCTest
@testable import MdreviewCore

final class FilesystemTests: XCTestCase {
    func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Root".write(to: root.appendingPathComponent("readme.MD"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "# Guide".write(to: root.appendingPathComponent("docs/guide.markdown"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try "# Ignored".write(to: root.appendingPathComponent("node_modules/ignored.md"), atomically: true, encoding: .utf8)
        try "plain".write(to: root.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        return root
    }

    func testMarkdownTreeSkipsHeavyDirectories() throws {
        let tree = try MarkdownTree.scan(root: makeFixture())
        let encoded = String(describing: tree)
        XCTAssertTrue(encoded.contains("readme.MD"))
        XCTAssertTrue(encoded.contains("guide.markdown"))
        XCTAssertFalse(encoded.contains("ignored.md"))
        XCTAssertFalse(encoded.contains("notes.txt"))
    }

    func testDefaultDocumentPrefersRootReadme() throws {
        let tree = try MarkdownTree.scan(root: makeFixture())
        XCTAssertEqual(MarkdownTree.defaultDocument(in: tree), "readme.MD")
    }

    func testPathValidationRejectsTraversal() throws {
        let root = makeFixture().resolvingSymlinksInPath()
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside.md")
        try "# Outside".write(to: outside, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try PathValidation.realPath(inside: root, relativePath: "../outside.md"))
    }

    func testResourceAuthorizerAllowsSiblingImageAndRejectsEscape() throws {
        let root = makeFixture().resolvingSymlinksInPath()
        try "image".write(to: root.appendingPathComponent("logo.png"), atomically: true, encoding: .utf8)
        let document = root.appendingPathComponent("readme.MD")
        let allowed = try ResourceAuthorizer(root: root).resolve(resource: "logo.png", from: document)
        XCTAssertEqual(allowed.lastPathComponent, "logo.png")
        XCTAssertThrowsError(try ResourceAuthorizer(root: root).resolve(resource: "../secret.png", from: document))
    }
}
```

- [ ] **Step 2: Run filesystem tests and verify failure**

Run:

```bash
swift test --package-path native --filter FilesystemTests
```

Expected:

```text
cannot find 'MarkdownTree' in scope
```

- [ ] **Step 3: Implement native filesystem helpers**

Create `native/Sources/MdreviewCore/PathValidation.swift`:

```swift
import Foundation

public enum PathValidationError: Error, Equatable {
    case pathEscapesRoot
    case unsupportedPath
}

public enum PathValidation {
    public static func canonicalURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    public static func realPath(inside root: URL, relativePath: String) throws -> URL {
        let candidate = root.appendingPathComponent(relativePath)
        let realRoot = canonicalURL(root)
        let realCandidate = canonicalURL(candidate)
        let rootPath = realRoot.path.hasSuffix("/") ? realRoot.path : realRoot.path + "/"
        if realCandidate.path == realRoot.path || realCandidate.path.hasPrefix(rootPath) {
            return realCandidate
        }
        throw PathValidationError.pathEscapesRoot
    }

    public static func isMarkdown(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".md") || lower.hasSuffix(".markdown")
    }
}
```

Create `native/Sources/MdreviewCore/MarkdownTree.swift`:

```swift
import Foundation

public struct MarkdownNode: Codable, Equatable, CustomStringConvertible {
    public enum NodeType: String, Codable { case file, directory }

    public let type: NodeType
    public let name: String
    public let path: String
    public let children: [MarkdownNode]

    public var description: String {
        "\(type.rawValue):\(path):\(children)"
    }
}

public enum MarkdownTree {
    private static let skipped = Set([".git", "node_modules", "dist", "build"])
    private static let readmeNames = Set(["readme.md", "readme.markdown"])

    public static func scan(root: URL, relativePath: String = "") throws -> [MarkdownNode] {
        let directory = relativePath.isEmpty ? root : root.appendingPathComponent(relativePath)
        let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey])
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var nodes: [MarkdownNode] = []
        for entry in entries {
            let name = entry.lastPathComponent
            let childRelative = relativePath.isEmpty ? name : "\(relativePath)/\(name)"
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if skipped.contains(name) { continue }
                let children = try scan(root: root, relativePath: childRelative)
                if !children.isEmpty {
                    nodes.append(MarkdownNode(type: .directory, name: name, path: childRelative, children: children))
                }
            } else if values.isRegularFile == true && PathValidation.isMarkdown(name) {
                nodes.append(MarkdownNode(type: .file, name: name, path: childRelative, children: []))
            }
        }
        return nodes
    }

    public static func flatten(_ nodes: [MarkdownNode]) -> [MarkdownNode] {
        nodes.flatMap { $0.type == .file ? [$0] : flatten($0.children) }
    }

    public static func defaultDocument(in nodes: [MarkdownNode]) -> String? {
        let files = flatten(nodes)
        if let readme = files.first(where: { readmeNames.contains($0.path.lowercased()) }) {
            return readme.path
        }
        return files.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }.first?.path
    }
}
```

Create `native/Sources/MdreviewCore/ResourceAuthorizer.swift`:

```swift
import Foundation

public struct ResourceAuthorizer {
    private let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func resolve(resource: String, from document: URL) throws -> URL {
        if resource.contains("://") {
            throw PathValidationError.unsupportedPath
        }
        let base = document.deletingLastPathComponent()
        let candidate = base.appendingPathComponent(resource).resolvingSymlinksInPath().standardizedFileURL
        let realRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let rootPrefix = realRoot.path.hasSuffix("/") ? realRoot.path : realRoot.path + "/"
        guard candidate.path == realRoot.path || candidate.path.hasPrefix(rootPrefix) else {
            throw PathValidationError.pathEscapesRoot
        }
        return candidate
    }
}
```

- [ ] **Step 4: Verify filesystem tests pass**

Run:

```bash
swift test --package-path native --filter FilesystemTests
```

Expected:

```text
FilesystemTests ... passed
```

- [ ] **Step 5: Commit filesystem utilities**

```bash
git add native/Sources/MdreviewCore native/Tests/MdreviewCoreTests
git commit -m "feat: add native filesystem boundaries"
```

### Task 3: Native App Model and Open Routing

**Files:**
- Create: `native/Sources/MdreviewCore/AppModel.swift`
- Create: `native/Sources/MdreviewCore/AppReducer.swift`
- Create: `native/Sources/MdreviewCore/SettingsStore.swift`
- Create: `native/Tests/MdreviewCoreTests/AppReducerTests.swift`

- [ ] **Step 1: Write failing reducer tests**

Create `native/Tests/MdreviewCoreTests/AppReducerTests.swift`:

```swift
import Foundation
import XCTest
@testable import MdreviewCore

final class AppReducerTests: XCTestCase {
    func testOpeningSameFileFocusesExistingTab() throws {
        let file = URL(fileURLWithPath: "/tmp/README.md")
        var model = AppModel()
        let first = AppReducer.apply(.openFile(file, newWindow: false), to: &model)
        let second = AppReducer.apply(.openFile(file, newWindow: false), to: &model)

        XCTAssertEqual(first, .opened)
        XCTAssertEqual(second, .focused)
        XCTAssertEqual(model.windows.count, 1)
        XCTAssertEqual(model.windows[0].tabs.count, 1)
    }

    func testDirectoryOpenReplacesWorkspaceAndClosesOldTabs() throws {
        var model = AppModel()
        _ = AppReducer.apply(.openFile(URL(fileURLWithPath: "/tmp/old.md"), newWindow: false), to: &model)
        _ = AppReducer.apply(.openDirectory(URL(fileURLWithPath: "/tmp/docs"), defaultDocument: URL(fileURLWithPath: "/tmp/docs/README.md"), newWindow: false), to: &model)

        XCTAssertEqual(model.windows.count, 1)
        XCTAssertEqual(model.windows[0].workspaceRoot?.path, "/tmp/docs")
        XCTAssertEqual(model.windows[0].tabs.map(\.url.path), ["/tmp/docs/README.md"])
    }

    func testNewWindowDirectoryCreatesSecondWindow() throws {
        var model = AppModel()
        _ = AppReducer.apply(.openDirectory(URL(fileURLWithPath: "/tmp/a"), defaultDocument: URL(fileURLWithPath: "/tmp/a/README.md"), newWindow: false), to: &model)
        _ = AppReducer.apply(.openDirectory(URL(fileURLWithPath: "/tmp/b"), defaultDocument: URL(fileURLWithPath: "/tmp/b/README.md"), newWindow: true), to: &model)

        XCTAssertEqual(model.windows.count, 2)
        XCTAssertEqual(model.windows[1].workspaceRoot?.path, "/tmp/b")
    }

    func testSingleFileWithoutWorkspaceUsesOutlineOnlyLayout() {
        var model = AppModel()
        _ = AppReducer.apply(.openFile(URL(fileURLWithPath: "/tmp/README.md"), newWindow: false), to: &model)
        XCTAssertEqual(model.windows[0].layoutMode, .outlineAndDocument)
    }
}
```

- [ ] **Step 2: Run reducer tests and verify failure**

Run:

```bash
swift test --package-path native --filter AppReducerTests
```

Expected:

```text
cannot find 'AppModel' in scope
```

- [ ] **Step 3: Implement model and reducer**

Create `native/Sources/MdreviewCore/AppModel.swift`:

```swift
import Foundation

public enum LayoutMode: String, Codable, Equatable {
    case filesOutlineAndDocument
    case outlineAndDocument
}

public struct DocumentTab: Codable, Equatable, Identifiable {
    public let id: UUID
    public let url: URL
    public var title: String
    public var scrollPosition: Double

    public init(id: UUID = UUID(), url: URL, title: String? = nil, scrollPosition: Double = 0) {
        self.id = id
        self.url = url
        self.title = title ?? url.lastPathComponent
        self.scrollPosition = scrollPosition
    }
}

public struct WindowModel: Codable, Equatable, Identifiable {
    public let id: UUID
    public var workspaceRoot: URL?
    public var tabs: [DocumentTab]
    public var activeTabID: UUID?
    public var layoutMode: LayoutMode

    public init(id: UUID = UUID(), workspaceRoot: URL? = nil, tabs: [DocumentTab] = [], activeTabID: UUID? = nil, layoutMode: LayoutMode = .outlineAndDocument) {
        self.id = id
        self.workspaceRoot = workspaceRoot
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.layoutMode = layoutMode
    }
}

public struct AppModel: Codable, Equatable {
    public var windows: [WindowModel]
    public var activeWindowID: UUID?

    public init(windows: [WindowModel] = [], activeWindowID: UUID? = nil) {
        self.windows = windows
        self.activeWindowID = activeWindowID
    }
}
```

Create `native/Sources/MdreviewCore/AppReducer.swift`:

```swift
import Foundation

public enum AppCommand {
    case openFile(URL, newWindow: Bool)
    case openDirectory(URL, defaultDocument: URL, newWindow: Bool)
}

public enum ReducerResult: Equatable {
    case opened
    case focused
}

public enum AppReducer {
    public static func apply(_ command: AppCommand, to model: inout AppModel) -> ReducerResult {
        switch command {
        case let .openFile(url, newWindow):
            return openFile(url, newWindow: newWindow, model: &model)
        case let .openDirectory(root, defaultDocument, newWindow):
            return openDirectory(root, defaultDocument: defaultDocument, newWindow: newWindow, model: &model)
        }
    }

    private static func openFile(_ url: URL, newWindow: Bool, model: inout AppModel) -> ReducerResult {
        for windowIndex in model.windows.indices {
            if let tab = model.windows[windowIndex].tabs.first(where: { $0.url.path == url.path }) {
                model.windows[windowIndex].activeTabID = tab.id
                model.activeWindowID = model.windows[windowIndex].id
                return .focused
            }
        }

        let tab = DocumentTab(url: url)
        if newWindow || model.windows.isEmpty {
            let window = WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument)
            model.windows.append(window)
            model.activeWindowID = window.id
            return .opened
        }

        let index = activeWindowIndex(in: model) ?? 0
        model.windows[index].tabs.append(tab)
        model.windows[index].activeTabID = tab.id
        if model.windows[index].workspaceRoot == nil {
            model.windows[index].layoutMode = .outlineAndDocument
        }
        model.activeWindowID = model.windows[index].id
        return .opened
    }

    private static func openDirectory(_ root: URL, defaultDocument: URL, newWindow: Bool, model: inout AppModel) -> ReducerResult {
        let tab = DocumentTab(url: defaultDocument)
        let replacement = WindowModel(workspaceRoot: root, tabs: [tab], activeTabID: tab.id, layoutMode: .filesOutlineAndDocument)

        if newWindow || model.windows.isEmpty {
            model.windows.append(replacement)
            model.activeWindowID = replacement.id
            return .opened
        }

        let index = activeWindowIndex(in: model) ?? 0
        model.windows[index] = WindowModel(id: model.windows[index].id, workspaceRoot: root, tabs: [tab], activeTabID: tab.id, layoutMode: .filesOutlineAndDocument)
        model.activeWindowID = model.windows[index].id
        return .opened
    }

    private static func activeWindowIndex(in model: AppModel) -> Array<WindowModel>.Index? {
        guard let id = model.activeWindowID else { return nil }
        return model.windows.firstIndex(where: { $0.id == id })
    }
}
```

Create `native/Sources/MdreviewCore/SettingsStore.swift`:

```swift
import Foundation

public struct AppSettings: Codable, Equatable {
    public var openFoldersInNewWindow: Bool
    public var autoRefreshSingleFile: Bool
    public var restoreLastWindow: Bool
    public var filesWidth: Double
    public var outlineWidth: Double
    public var showFiles: Bool
    public var showOutline: Bool

    public init(openFoldersInNewWindow: Bool, autoRefreshSingleFile: Bool, restoreLastWindow: Bool, filesWidth: Double, outlineWidth: Double, showFiles: Bool, showOutline: Bool) {
        self.openFoldersInNewWindow = openFoldersInNewWindow
        self.autoRefreshSingleFile = autoRefreshSingleFile
        self.restoreLastWindow = restoreLastWindow
        self.filesWidth = filesWidth
        self.outlineWidth = outlineWidth
        self.showFiles = showFiles
        self.showOutline = showOutline
    }

    public static let defaults = AppSettings(
        openFoldersInNewWindow: false,
        autoRefreshSingleFile: true,
        restoreLastWindow: false,
        filesWidth: 220,
        outlineWidth: 180,
        showFiles: true,
        showOutline: true
    )
}
```

- [ ] **Step 4: Verify reducer tests pass**

Run:

```bash
swift test --package-path native --filter AppReducerTests
```

Expected:

```text
AppReducerTests ... passed
```

- [ ] **Step 5: Commit app model**

```bash
git add native/Sources/MdreviewCore native/Tests/MdreviewCoreTests
git commit -m "feat: add native app routing model"
```

### Task 4: CLI Parser and Unix Socket Handoff

**Files:**
- Modify: `src/cli/args.ts`
- Modify: `src/cli/index.ts`
- Create: `src/cli/native-client.ts`
- Modify: `tests/cli/args.test.ts`
- Create: `tests/cli/native-client.test.ts`
- Create: `native/Sources/MdreviewIPC/SocketServer.swift`
- Create: `native/Tests/MdreviewIPCTests/SocketServerTests.swift`

- [ ] **Step 1: Update failing CLI parser tests**

Replace `tests/cli/args.test.ts` with:

```ts
import { describe, expect, it } from "vitest";
import { HELP_TEXT, parseArgs } from "../../src/cli/args";

describe("parseArgs", () => {
  it("parses file path and new-window", () => {
    expect(parseArgs(["docs", "--new-window"])).toEqual({
      action: "open",
      path: "docs",
      newWindow: true
    });
  });

  it("defaults to reusing an existing window", () => {
    expect(parseArgs(["README.md"])).toEqual({
      action: "open",
      path: "README.md",
      newWindow: false
    });
  });

  it("returns help and version actions without requiring a path", () => {
    expect(parseArgs(["--help"])).toEqual({ action: "help" });
    expect(parseArgs(["--version"])).toEqual({ action: "version" });
  });

  it("rejects removed browser-server flags", () => {
    expect(() => parseArgs(["docs", "--port", "4010"])).toThrow("不再支持参数：--port");
    expect(() => parseArgs(["docs", "--no-open"])).toThrow("不再支持参数：--no-open");
  });

  it("prints Chinese help text", () => {
    expect(HELP_TEXT).toContain("用法：mdreview <文件或目录>");
  });
});
```

- [ ] **Step 2: Add failing Node socket client tests**

Create `tests/cli/native-client.test.ts`:

```ts
import net from "node:net";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { sendOpenRequest } from "../../src/cli/native-client";

let cleanupPath: string | undefined;

afterEach(async () => {
  if (cleanupPath) await rm(cleanupPath, { force: true });
  cleanupPath = undefined;
});

describe("native app socket client", () => {
  it("sends an open request and reads an ack", async () => {
    const dir = await mkdtemp(path.join(tmpdir(), "mdreview-ipc-"));
    const socketPath = path.join(dir, "mdreview.sock");
    cleanupPath = socketPath;

    const server = net.createServer((socket) => {
      socket.on("data", (chunk) => {
        const message = JSON.parse(chunk.toString("utf8"));
        expect(message).toMatchObject({ kind: "openFile", path: "/tmp/README.md", newWindow: false });
        socket.end(JSON.stringify({ accepted: true, action: "opened", message: "已打开" }) + "\n");
      });
    });

    await new Promise<void>((resolve) => server.listen(socketPath, resolve));
    const response = await sendOpenRequest(socketPath, { kind: "openFile", path: "/tmp/README.md", newWindow: false }, 1000);
    server.close();

    expect(response).toEqual({ accepted: true, action: "opened", message: "已打开" });
  });
});
```

- [ ] **Step 3: Run CLI tests and verify failure**

Run:

```bash
npm test -- tests/cli/args.test.ts tests/cli/native-client.test.ts
```

Expected:

```text
Cannot find module '../../src/cli/native-client'
```

- [ ] **Step 4: Implement TypeScript CLI handoff**

Replace `src/cli/args.ts`:

```ts
export type CliOptions =
  | { action: "open"; path: string; newWindow: boolean }
  | { action: "help" }
  | { action: "version" };

export const HELP_TEXT = "用法：mdreview <文件或目录> [--new-window]\n\n选项：\n  --new-window  在新窗口中打开目录或文件\n  --help        显示帮助\n  --version     显示版本";
export const VERSION = "0.1.0";

const removedFlags = new Set(["--port", "--no-open"]);

export function parseArgs(argv: string[]): CliOptions {
  if (argv.includes("--help")) return { action: "help" };
  if (argv.includes("--version")) return { action: "version" };

  let inputPath: string | undefined;
  let newWindow = false;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (removedFlags.has(arg)) throw new Error(`不再支持参数：${arg}`);
    if (arg === "--new-window") {
      newWindow = true;
      continue;
    }
    if (!arg.startsWith("-") && !inputPath) {
      inputPath = arg;
      continue;
    }
    throw new Error(`未知参数：${arg}`);
  }

  if (!inputPath) throw new Error("用法：mdreview <文件或目录>");
  return { action: "open", path: inputPath, newWindow };
}
```

Create `src/cli/native-client.ts`:

```ts
import net from "node:net";

export type NativeOpenRequest = {
  kind: "openFile" | "openDirectory";
  path: string;
  newWindow: boolean;
};

export type NativeOpenResponse = {
  accepted: boolean;
  action: "opened" | "focused" | "rejected";
  message: string;
};

export function defaultSocketPath(env = process.env): string {
  const base = env.TMPDIR ?? "/tmp/";
  const trimmed = base.endsWith("/") ? base.slice(0, -1) : base;
  return `${trimmed}/mdreview-${process.getuid?.() ?? 0}.sock`;
}

export async function sendOpenRequest(socketPath: string, request: NativeOpenRequest, timeoutMs: number): Promise<NativeOpenResponse> {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error("等待 mdreview App 响应超时"));
    }, timeoutMs);

    let buffer = "";
    socket.on("connect", () => {
      socket.write(JSON.stringify(request) + "\n");
    });
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      if (!buffer.includes("\n")) return;
      clearTimeout(timer);
      socket.end();
      resolve(JSON.parse(buffer.trim()) as NativeOpenResponse);
    });
    socket.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}
```

Replace `src/cli/index.ts`:

```ts
#!/usr/bin/env node
import { spawn } from "node:child_process";
import { rm, stat } from "node:fs/promises";
import path from "node:path";
import { HELP_TEXT, VERSION, parseArgs } from "./args";
import { defaultSocketPath, sendOpenRequest, type NativeOpenRequest } from "./native-client";

async function launchApp() {
  const explicitApp = process.env.MDREVIEW_APP_PATH;
  const child = explicitApp
    ? spawn("open", [explicitApp], { stdio: "ignore", detached: true })
    : spawn("open", ["-a", "mdreview"], { stdio: "ignore", detached: true });
  child.unref();
}

async function waitForApp(socketPath: string, request: NativeOpenRequest) {
  const started = Date.now();
  let lastError: unknown;
  while (Date.now() - started < 5_000) {
    try {
      return await sendOpenRequest(socketPath, request, 2_000);
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 150));
    }
  }
  throw lastError instanceof Error ? lastError : new Error("无法连接 mdreview App");
}

async function main() {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.action === "help") {
      console.log(HELP_TEXT);
      return;
    }
    if (options.action === "version") {
      console.log(VERSION);
      return;
    }

    const absolutePath = path.resolve(options.path);
    const stats = await stat(absolutePath).catch(() => {
      throw new Error(`路径不存在：${options.path}`);
    });
    if (!stats.isFile() && !stats.isDirectory()) {
      throw new Error(`路径不是文件或目录：${options.path}`);
    }

    const request: NativeOpenRequest = {
      kind: stats.isDirectory() ? "openDirectory" : "openFile",
      path: absolutePath,
      newWindow: options.newWindow
    };
    const socketPath = defaultSocketPath();

    let response;
    try {
      response = await sendOpenRequest(socketPath, request, 2_000);
    } catch {
      await rm(socketPath, { force: true }).catch(() => undefined);
      await launchApp();
      response = await waitForApp(socketPath, request);
    }

    if (!response.accepted) {
      throw new Error(response.message);
    }
    console.log(response.message);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void main();
```

- [ ] **Step 5: Add Swift socket server test**

Create `native/Tests/MdreviewIPCTests/SocketServerTests.swift`:

```swift
import Foundation
import Network
import XCTest
@testable import MdreviewCore
@testable import MdreviewIPC

final class SocketServerTests: XCTestCase {
    func testResponseEncodingMatchesCliContract() throws {
        let response = OpenResponse(accepted: true, action: .focused, message: "已聚焦")
        let data = try SocketCodec.encode(response)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"accepted":true,"action":"focused","message":"已聚焦"}"# + "\n")
    }

    func testSocketServerReceivesRequestAndReplies() throws {
        let socketPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdreview-ipc-\(UUID().uuidString).sock")
            .path
        let server = try SocketServer(socketPath: socketPath) { request in
            XCTAssertEqual(request.kind, .openFile)
            XCTAssertEqual(request.path, "/tmp/README.md")
            return OpenResponse(accepted: true, action: .opened, message: "已打开")
        }
        try server.start()
        defer { server.stop() }

        let expectation = expectation(description: "response received")
        let connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
        var received = ""

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                let request = #"{"kind":"openFile","path":"/tmp/README.md","newWindow":false}"# + "\n"
                connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
            }
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
            received = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            expectation.fulfill()
        }
        connection.start(queue: .global())

        wait(for: [expectation], timeout: 2)
        connection.cancel()
        XCTAssertEqual(received, #"{"accepted":true,"action":"opened","message":"已打开"}"# + "\n")
    }
}
```

- [ ] **Step 6: Implement Swift socket codec and server**

Create `native/Sources/MdreviewIPC/SocketServer.swift`:

```swift
import Foundation
import Network
import MdreviewCore

public enum SocketCodec {
    public static func decodeRequest(_ data: Data) throws -> OpenRequest {
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return try JSONDecoder().decode(OpenRequest.self, from: Data(trimmed.utf8))
    }

    public static func encode(_ response: OpenResponse) throws -> Data {
        var data = try JSONEncoder().encode(response)
        data.append(0x0A)
        return data
    }
}

public final class SocketServer {
    private let socketPath: String
    private let handler: (OpenRequest) -> OpenResponse
    private let queue = DispatchQueue(label: "mdreview.ipc.socket")
    private var listener: NWListener?

    public init(socketPath: String, handler: @escaping (OpenRequest) -> OpenResponse) throws {
        self.socketPath = socketPath
        self.handler = handler
    }

    public func start() throws {
        if FileManager.default.fileExists(atPath: socketPath) {
            try FileManager.default.removeItem(atPath: socketPath)
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: socketPath)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [handler] connection in
            connection.start(queue: self.queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, _ in
                guard let data else {
                    connection.cancel()
                    return
                }
                let response: OpenResponse
                do {
                    let request = try SocketCodec.decodeRequest(data)
                    response = handler(request)
                } catch {
                    response = OpenResponse(accepted: false, action: .rejected, message: "无法解析打开请求")
                }
                let encoded = (try? SocketCodec.encode(response)) ?? Data()
                connection.send(content: encoded, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        try? FileManager.default.removeItem(atPath: socketPath)
    }
}
```

- [ ] **Step 7: Verify IPC tests**

Run:

```bash
npm test -- tests/cli/args.test.ts tests/cli/native-client.test.ts
swift test --package-path native --filter SocketServerTests
```

Expected:

```text
PASS tests/cli/args.test.ts
PASS tests/cli/native-client.test.ts
SocketServerTests ... passed
```

- [ ] **Step 8: Commit IPC handoff**

```bash
git add src/cli tests/cli native/Sources/MdreviewIPC native/Tests/MdreviewIPCTests
git commit -m "feat: add native app CLI handoff"
```

### Task 5: Renderer Bridge Shell

**Files:**
- Create: `src/web/renderer/bridge.ts`
- Create: `src/web/renderer/resources.ts`
- Create: `src/web/renderer/RendererApp.tsx`
- Modify: `src/web/main.tsx`
- Modify: `src/web/App.tsx`
- Create: `tests/web/renderer/bridge.test.ts`
- Create: `tests/web/renderer/resources.test.ts`
- Create: `tests/web/renderer/RendererApp.test.tsx`

- [ ] **Step 1: Write failing renderer bridge tests**

Create `tests/web/renderer/resources.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { rewriteMarkdownResources } from "../../../src/web/renderer/resources";

describe("rewriteMarkdownResources", () => {
  it("rewrites relative markdown images to mdreview-resource URLs", () => {
    expect(rewriteMarkdownResources("![Logo](./logo.png)")).toBe("![Logo](mdreview-resource://./logo.png)");
  });

  it("keeps remote URLs unchanged", () => {
    expect(rewriteMarkdownResources("![Logo](https://example.com/logo.png)")).toBe("![Logo](https://example.com/logo.png)");
  });
});
```

Create `tests/web/renderer/bridge.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { createNativeBridge } from "../../../src/web/renderer/bridge";

describe("native bridge", () => {
  it("posts outlineChanged to the native message handler", () => {
    const postMessage = vi.fn();
    const bridge = createNativeBridge({ mdreview: { postMessage } });
    bridge.outlineChanged([{ id: "hello", text: "Hello", depth: 1 }]);
    expect(postMessage).toHaveBeenCalledWith({ type: "outlineChanged", items: [{ id: "hello", text: "Hello", depth: 1 }] });
  });
});
```

- [ ] **Step 2: Run renderer bridge tests and verify failure**

Run:

```bash
npm test -- tests/web/renderer/resources.test.ts tests/web/renderer/bridge.test.ts
```

Expected:

```text
Cannot find module '../../../src/web/renderer/resources'
```

- [ ] **Step 3: Implement bridge and resource rewriting**

Create `src/web/renderer/bridge.ts`:

```ts
import type { OutlineItem } from "../components/Outline";

type HandlerMap = {
  mdreview?: {
    postMessage: (message: unknown) => void;
  };
};

export type NativeBridge = {
  outlineChanged: (items: OutlineItem[]) => void;
  scrollChanged: (path: string, scrollPosition: number) => void;
  renderError: (path: string, message: string, blockId?: string) => void;
};

export function createNativeBridge(handlers: HandlerMap = window.webkit?.messageHandlers ?? {}): NativeBridge {
  function post(message: unknown) {
    handlers.mdreview?.postMessage(message);
  }
  return {
    outlineChanged: (items) => post({ type: "outlineChanged", items }),
    scrollChanged: (path, scrollPosition) => post({ type: "scrollChanged", path, scrollPosition }),
    renderError: (path, message, blockId) => post({ type: "renderError", path, message, blockId })
  };
}

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: HandlerMap;
    };
  }
}
```

Create `src/web/renderer/resources.ts`:

```ts
const remotePattern = /^[a-z][a-z0-9+.-]*:/i;

export function rewriteMarkdownResources(content: string): string {
  return content.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (match, alt: string, rawUrl: string) => {
    const url = rawUrl.trim();
    if (remotePattern.test(url) || url.startsWith("#")) return match;
    return `![${alt}](mdreview-resource://${url})`;
  });
}
```

- [ ] **Step 4: Add bridge-driven renderer component**

Create `src/web/renderer/RendererApp.tsx`:

```tsx
import { useCallback, useEffect, useMemo, useState } from "react";
import { MarkdownView } from "../components/MarkdownView";
import type { OutlineItem } from "../components/Outline";
import { createNativeBridge } from "./bridge";
import { rewriteMarkdownResources } from "./resources";

export type RenderDocumentMessage = {
  type: "renderDocument";
  path: string;
  name: string;
  content: string;
  scrollPosition?: number;
};

export function RendererApp() {
  const bridge = useMemo(() => createNativeBridge(), []);
  const [document, setDocument] = useState<RenderDocumentMessage | null>(null);

  useEffect(() => {
    window.__mdreviewRenderDocument = setDocument;
    return () => {
      delete window.__mdreviewRenderDocument;
    };
  }, []);

  const onOutline = useCallback((items: OutlineItem[]) => {
    bridge.outlineChanged(items);
  }, [bridge]);

  if (!document) {
    return <main className="renderer-empty">等待文档...</main>;
  }

  return (
    <article className="markdown-body">
      <MarkdownView content={rewriteMarkdownResources(document.content)} onOutline={onOutline} />
    </article>
  );
}

declare global {
  interface Window {
    __mdreviewRenderDocument?: (message: RenderDocumentMessage) => void;
  }
}
```

- [ ] **Step 5: Verify renderer bridge**

Run:

```bash
npm test -- tests/web/renderer/resources.test.ts tests/web/renderer/bridge.test.ts tests/web/MarkdownView.test.tsx
npm run typecheck
```

Expected:

```text
PASS tests/web/renderer/resources.test.ts
PASS tests/web/renderer/bridge.test.ts
No TypeScript errors.
```

- [ ] **Step 6: Commit renderer bridge**

```bash
git add src/web tests/web
git commit -m "feat: add WKWebView renderer bridge"
```

### Task 6: AppKit Window, Chinese Menus, and Layout Controllers

**Files:**
- Create: `native/Sources/MdreviewApp/AppDelegate.swift`
- Create: `native/Sources/MdreviewApp/MainWindowController.swift`
- Create: `native/Sources/MdreviewApp/DocumentTabBar.swift`
- Create: `native/Sources/MdreviewApp/SidebarController.swift`
- Create: `native/Sources/MdreviewApp/SettingsWindowController.swift`
- Modify: `native/Sources/MdreviewApp/main.swift`
- Create: `native/Tests/MdreviewCoreTests/MenuTextTests.swift`

- [ ] **Step 1: Write failing menu text test**

Create `native/Tests/MdreviewCoreTests/MenuTextTests.swift`:

```swift
import XCTest
@testable import MdreviewCore

final class MenuTextTests: XCTestCase {
    func testChineseMenuTitles() {
        XCTAssertEqual(MenuText.openFile, "打开文件...")
        XCTAssertEqual(MenuText.openFolder, "打开文件夹...")
        XCTAssertEqual(MenuText.openFolderInNewWindow, "在新窗口中打开文件夹...")
        XCTAssertEqual(MenuText.reloadCurrentDocument, "重新载入当前文档")
    }
}
```

- [ ] **Step 2: Run menu text test and verify failure**

Run:

```bash
swift test --package-path native --filter MenuTextTests
```

Expected:

```text
cannot find 'MenuText' in scope
```

- [ ] **Step 3: Add menu text constants**

Create `native/Sources/MdreviewCore/MenuText.swift`:

```swift
public enum MenuText {
    public static let appName = "mdreview"
    public static let settings = "设置..."
    public static let file = "文件"
    public static let openFile = "打开文件..."
    public static let openFolder = "打开文件夹..."
    public static let openFolderInNewWindow = "在新窗口中打开文件夹..."
    public static let closeTab = "关闭标签页"
    public static let closeWindow = "关闭窗口"
    public static let view = "视图"
    public static let toggleFiles = "显示/隐藏文件"
    public static let toggleOutline = "显示/隐藏大纲"
    public static let reloadCurrentDocument = "重新载入当前文档"
    public static let window = "窗口"
}
```

- [ ] **Step 4: Implement AppKit shell**

Update `native/Sources/MdreviewApp/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
```

Create `native/Sources/MdreviewApp/AppDelegate.swift`:

```swift
import AppKit
import MdreviewCore
import MdreviewIPC

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [MainWindowController] = []
    private var model = AppModel()
    private var socketServer: SocketServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = buildMenu()
        startIPCServer()
        openEmptyWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
    }

    private func openEmptyWindow() {
        createWindow(activate: true)
    }

    private func createWindow(activate: Bool) {
        let controller = MainWindowController()
        windows.append(controller)
        controller.showWindow(nil)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func startIPCServer() {
        do {
            let server = try SocketServer(socketPath: SocketLocation.defaultPath()) { [weak self] request in
                guard let self else {
                    return OpenResponse(accepted: false, action: .rejected, message: "App 尚未就绪")
                }
                return DispatchQueue.main.sync {
                    self.handleOpenRequest(request)
                }
            }
            try server.start()
            socketServer = server
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法启动命令行入口"
            alert.informativeText = String(describing: error)
            alert.runModal()
        }
    }

    @discardableResult
    private func handleOpenRequest(_ request: OpenRequest) -> OpenResponse {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: request.path, isDirectory: &isDirectory) else {
            return OpenResponse(accepted: false, action: .rejected, message: "路径不存在：\(request.path)")
        }

        let url = PathValidation.canonicalURL(URL(fileURLWithPath: request.path))
        let result: ReducerResult
        switch request.kind {
        case .openFile:
            guard !isDirectory.boolValue else {
                return OpenResponse(accepted: false, action: .rejected, message: "路径不是文件：\(request.path)")
            }
            result = AppReducer.apply(.openFile(url, newWindow: request.newWindow), to: &model)
        case .openDirectory:
            guard isDirectory.boolValue else {
                return OpenResponse(accepted: false, action: .rejected, message: "路径不是目录：\(request.path)")
            }
            do {
                let tree = try MarkdownTree.scan(root: url)
                guard let defaultRelativePath = MarkdownTree.defaultDocument(in: tree) else {
                    return OpenResponse(accepted: false, action: .rejected, message: "目录中没有 Markdown 文件：\(request.path)")
                }
                let defaultDocument = url.appendingPathComponent(defaultRelativePath)
                result = AppReducer.apply(.openDirectory(url, defaultDocument: defaultDocument, newWindow: request.newWindow), to: &model)
            } catch {
                return OpenResponse(accepted: false, action: .rejected, message: "无法扫描目录：\(request.path)")
            }
        }

        synchronizeWindows()
        let action: OpenResponseAction = result == .focused ? .focused : .opened
        return OpenResponse(accepted: true, action: action, message: result == .focused ? "已聚焦" : "已打开")
    }

    private func synchronizeWindows() {
        while windows.count < model.windows.count {
            createWindow(activate: false)
        }
        for (index, windowModel) in model.windows.enumerated() {
            windows[index].apply(windowModel: windowModel)
        }
        if let activeID = model.activeWindowID,
           let activeIndex = model.windows.firstIndex(where: { $0.id == activeID }) {
            windows[activeIndex].showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func buildMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: MenuText.appName)
        appMenu.addItem(NSMenuItem(title: MenuText.settings, action: #selector(openSettings), keyEquivalent: ","))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: MenuText.file)
        fileMenu.addItem(NSMenuItem(title: MenuText.openFile, action: #selector(openFile), keyEquivalent: "o"))
        fileMenu.addItem(NSMenuItem(title: MenuText.openFolder, action: #selector(openFolder), keyEquivalent: "O"))
        fileMenu.addItem(NSMenuItem(title: MenuText.openFolderInNewWindow, action: #selector(openFolderInNewWindow), keyEquivalent: "n"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: MenuText.closeTab, action: #selector(closeTab), keyEquivalent: "w"))
        fileMenu.addItem(NSMenuItem(title: MenuText.closeWindow, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "W"))
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: MenuText.view)
        viewMenu.addItem(NSMenuItem(title: MenuText.toggleFiles, action: #selector(toggleFiles), keyEquivalent: "1"))
        viewMenu.addItem(NSMenuItem(title: MenuText.toggleOutline, action: #selector(toggleOutline), keyEquivalent: "2"))
        viewMenu.addItem(NSMenuItem(title: MenuText.reloadCurrentDocument, action: #selector(reloadDocument), keyEquivalent: "r"))
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        main.addItem(NSMenuItem(title: MenuText.window, action: nil, keyEquivalent: ""))
        return main
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow(nil)
    }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            _ = handleOpenRequest(OpenRequest(kind: .openFile, path: url.path, newWindow: false))
        }
    }

    @objc private func openFolder() {
        openFolder(newWindow: false)
    }

    @objc private func openFolderInNewWindow() {
        openFolder(newWindow: true)
    }

    private func openFolder(newWindow: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            _ = handleOpenRequest(OpenRequest(kind: .openDirectory, path: url.path, newWindow: newWindow))
        }
    }

    @objc private func closeTab() {}
    @objc private func toggleFiles() {}
    @objc private func toggleOutline() {}
    @objc private func reloadDocument() {}
}
```

Create `native/Sources/MdreviewApp/MainWindowController.swift`:

```swift
import AppKit
import MdreviewCore

final class MainWindowController: NSWindowController {
    private let splitView = NSSplitView()
    private let tabBar = DocumentTabBar()
    private let sidebar = SidebarController()
    private let content = NSTextView()
    private var didBuildLayout = false

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        self.init(window: window)
        window.title = "mdreview"
        buildLayout()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        buildLayout()
    }

    private func buildLayout() {
        guard !didBuildLayout else { return }
        guard let root = window?.contentView else { return }
        didBuildLayout = true
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        stack.addArrangedSubview(tabBar.view)
        stack.addArrangedSubview(splitView)
        tabBar.view.heightAnchor.constraint(equalToConstant: 34).isActive = true
        splitView.addArrangedSubview(sidebar.filesView)
        splitView.addArrangedSubview(sidebar.outlineView)
        let contentScrollView = NSScrollView()
        contentScrollView.documentView = content
        contentScrollView.hasVerticalScroller = true
        splitView.addArrangedSubview(contentScrollView)
        sidebar.filesView.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        sidebar.outlineView.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        content.string = "请选择 Markdown 文件"
        content.isEditable = false
    }

    func apply(windowModel: WindowModel) {
        tabBar.render(tabs: windowModel.tabs, activeTabID: windowModel.activeTabID)
        sidebar.apply(layoutMode: windowModel.layoutMode)
        let active = windowModel.tabs.first(where: { $0.id == windowModel.activeTabID })
        window?.title = active?.title ?? "mdreview"
    }
}
```

Create `native/Sources/MdreviewApp/DocumentTabBar.swift`:

```swift
import AppKit
import MdreviewCore

final class DocumentTabBar: NSObject {
    let view = NSStackView()
    var onSelectTab: ((UUID) -> Void)?

    override init() {
        super.init()
        view.orientation = .horizontal
        view.alignment = .centerY
        view.spacing = 0
        view.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    }

    func render(tabs: [DocumentTab], activeTabID: UUID?) {
        view.arrangedSubviews.forEach { subview in
            view.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        for tab in tabs {
            let button = NSButton(title: tab.title, target: self, action: #selector(selectTab(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(tab.id.uuidString)
            button.bezelStyle = tab.id == activeTabID ? .rounded : .texturedRounded
            view.addArrangedSubview(button)
        }
        if tabs.isEmpty {
            view.addArrangedSubview(NSTextField(labelWithString: "未打开文档"))
        }
    }

    @objc private func selectTab(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        onSelectTab?(id)
    }
}
```

Create `native/Sources/MdreviewApp/SidebarController.swift`:

```swift
import AppKit
import MdreviewCore

final class SidebarController {
    let filesView = NSScrollView()
    let outlineView = NSScrollView()

    init() {
        filesView.documentView = NSTextField(labelWithString: "文件")
        outlineView.documentView = NSTextField(labelWithString: "大纲")
        filesView.borderType = .noBorder
        outlineView.borderType = .noBorder
        filesView.hasVerticalScroller = true
        outlineView.hasVerticalScroller = true
    }

    func apply(layoutMode: LayoutMode) {
        filesView.isHidden = layoutMode == .outlineAndDocument
    }
}
```

Create `native/Sources/MdreviewApp/SettingsWindowController.swift`:

```swift
import AppKit

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "设置"
        let label = NSTextField(labelWithString: "设置")
        label.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(label)
        if let contentView = window.contentView {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20)
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
```

- [ ] **Step 5: Verify native shell builds**

Run:

```bash
swift test --package-path native --filter MenuTextTests
swift build --package-path native
```

Expected:

```text
MenuTextTests ... passed
Build complete
```

- [ ] **Step 6: Commit app shell**

```bash
git add native/Sources/MdreviewApp native/Sources/MdreviewCore native/Tests/MdreviewCoreTests
git commit -m "feat: add native window shell and Chinese menus"
```

### Task 7: WKWebView Renderer Controller and Resource Scheme

**Files:**
- Create: `native/Sources/MdreviewApp/RendererViewController.swift`
- Create: `native/Sources/MdreviewApp/ResourceSchemeHandler.swift`
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Create: `native/Tests/MdreviewCoreTests/ResourceSchemeTests.swift`

- [ ] **Step 1: Write failing resource scheme tests**

Create `native/Tests/MdreviewCoreTests/ResourceSchemeTests.swift`:

```swift
import Foundation
import XCTest
@testable import MdreviewCore

final class ResourceSchemeTests: XCTestCase {
    func testParsesMdreviewResourceURL() throws {
        let parsed = try ResourceURL.parse(URL(string: "mdreview-resource://./images/logo.png")!)
        XCTAssertEqual(parsed, "./images/logo.png")
    }
}
```

- [ ] **Step 2: Implement resource URL parser**

Create `native/Sources/MdreviewCore/ResourceURL.swift`:

```swift
import Foundation

public enum ResourceURLError: Error {
    case invalidScheme
    case missingPath
}

public enum ResourceURL {
    public static func parse(_ url: URL) throws -> String {
        guard url.scheme == "mdreview-resource" else { throw ResourceURLError.invalidScheme }
        let host = url.host ?? ""
        let path = url.path
        let combined = host + path
        guard !combined.isEmpty else { throw ResourceURLError.missingPath }
        return combined.removingPercentEncoding ?? combined
    }
}
```

- [ ] **Step 3: Add WKWebView controller**

Create `native/Sources/MdreviewApp/RendererViewController.swift`:

```swift
import AppKit
import WebKit
import MdreviewCore

final class RendererViewController: NSViewController, WKScriptMessageHandler {
    private let webView: WKWebView

    init(resourceHandler: ResourceSchemeHandler) {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(resourceHandler, forURLScheme: "mdreview-resource")
        let contentController = WKUserContentController()
        configuration.userContentController = contentController
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        contentController.add(self, name: "mdreview")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = webView
    }

    func loadRenderer(from url: URL) {
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func render(path: String, name: String, content: String, scrollPosition: Double?) {
        let payload: [String: Any] = ["type": "renderDocument", "path": path, "name": name, "content": content, "scrollPosition": scrollPosition ?? 0]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.__mdreviewRenderDocument && window.__mdreviewRenderDocument(\(json));")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // The window controller owns state routing; this controller only receives renderer messages.
    }
}
```

Create `native/Sources/MdreviewApp/ResourceSchemeHandler.swift`:

```swift
import Foundation
import WebKit
import MdreviewCore

final class ResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    var root: URL?
    var currentDocument: URL?

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let root, let currentDocument else {
            urlSchemeTask.didFailWithError(PathValidationError.unsupportedPath)
            return
        }
        do {
            let resource = try ResourceURL.parse(urlSchemeTask.request.url!)
            let file = try ResourceAuthorizer(root: root).resolve(resource: resource, from: currentDocument)
            let data = try Data(contentsOf: file)
            let response = URLResponse(url: urlSchemeTask.request.url!, mimeType: mimeType(for: file), expectedContentLength: data.count, textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        default: return "application/octet-stream"
        }
    }
}
```

Update `native/Sources/MdreviewApp/MainWindowController.swift` to replace the temporary text content with the renderer:

```swift
private let resourceHandler = ResourceSchemeHandler()
private lazy var renderer = RendererViewController(resourceHandler: resourceHandler)
```

In `buildLayout()`, replace the `NSTextView` scroll view with:

```swift
splitView.addArrangedSubview(renderer.view)
```

In `apply(windowModel:)`, after setting the title, render the active tab:

```swift
if let active = active {
    render(tab: active, workspaceRoot: windowModel.workspaceRoot)
}
```

Add this helper to `MainWindowController`:

```swift
private func render(tab: DocumentTab, workspaceRoot: URL?) {
    resourceHandler.root = workspaceRoot ?? tab.url.deletingLastPathComponent()
    resourceHandler.currentDocument = tab.url
    do {
        let content = try String(contentsOf: tab.url, encoding: .utf8)
        renderer.render(path: tab.url.path, name: tab.title, content: content, scrollPosition: tab.scrollPosition)
    } catch {
        renderer.render(path: tab.url.path, name: tab.title, content: "文件不存在：\(tab.url.path)", scrollPosition: tab.scrollPosition)
    }
}
```

- [ ] **Step 4: Verify WKWebView code builds**

Run:

```bash
swift test --package-path native --filter ResourceSchemeTests
swift build --package-path native
```

Expected:

```text
ResourceSchemeTests ... passed
Build complete
```

- [ ] **Step 5: Commit renderer controller**

```bash
git add native/Sources/MdreviewApp native/Sources/MdreviewCore native/Tests/MdreviewCoreTests
git commit -m "feat: add WKWebView renderer controller"
```

### Task 8: Workspace UI, Tabs, Files, Outline, and Settings

**Files:**
- Modify: `native/Sources/MdreviewApp/AppDelegate.swift`
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`
- Modify: `native/Sources/MdreviewApp/DocumentTabBar.swift`
- Modify: `native/Sources/MdreviewApp/SidebarController.swift`
- Modify: `native/Sources/MdreviewApp/SettingsWindowController.swift`
- Modify: `native/Sources/MdreviewCore/SettingsStore.swift`
- Create: `native/Tests/MdreviewCoreTests/SettingsTests.swift`

- [ ] **Step 1: Add settings persistence tests**

Create `native/Tests/MdreviewCoreTests/SettingsTests.swift`:

```swift
import XCTest
@testable import MdreviewCore

final class SettingsTests: XCTestCase {
    func testDefaultSettingsMatchSpec() {
        let defaults = AppSettings.defaults
        XCTAssertFalse(defaults.openFoldersInNewWindow)
        XCTAssertTrue(defaults.autoRefreshSingleFile)
        XCTAssertFalse(defaults.restoreLastWindow)
        XCTAssertEqual(defaults.filesWidth, 220)
        XCTAssertEqual(defaults.outlineWidth, 180)
    }

    func testSettingsPersistToUserDefaults() {
        let suite = "mdreview.settings.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(
            openFoldersInNewWindow: true,
            autoRefreshSingleFile: false,
            restoreLastWindow: true,
            filesWidth: 260,
            outlineWidth: 210,
            showFiles: false,
            showOutline: true
        )
        SettingsStore.save(settings, defaults: defaults)

        XCTAssertEqual(SettingsStore.load(defaults: defaults), settings)
    }
}
```

- [ ] **Step 2: Confirm visible tab/sidebar behavior**

`DocumentTabBar` from Task 6 already renders one native button per `DocumentTab` and exposes `onSelectTab`. Keep `SidebarController.apply(layoutMode:)` as the single source of truth for single-file layout:

```swift
func apply(layoutMode: LayoutMode) {
    filesView.isHidden = layoutMode == .outlineAndDocument
}
```

Update `MainWindowController` with:

```swift
func apply(windowModel: WindowModel) {
    tabBar.render(tabs: windowModel.tabs, activeTabID: windowModel.activeTabID)
    sidebar.apply(layoutMode: windowModel.layoutMode)
}
```

- [ ] **Step 3: Add Chinese settings window**

Replace `native/Sources/MdreviewCore/SettingsStore.swift` with:

```swift
import Foundation

public struct AppSettings: Codable, Equatable {
    public var openFoldersInNewWindow: Bool
    public var autoRefreshSingleFile: Bool
    public var restoreLastWindow: Bool
    public var filesWidth: Double
    public var outlineWidth: Double
    public var showFiles: Bool
    public var showOutline: Bool

    public init(openFoldersInNewWindow: Bool, autoRefreshSingleFile: Bool, restoreLastWindow: Bool, filesWidth: Double, outlineWidth: Double, showFiles: Bool, showOutline: Bool) {
        self.openFoldersInNewWindow = openFoldersInNewWindow
        self.autoRefreshSingleFile = autoRefreshSingleFile
        self.restoreLastWindow = restoreLastWindow
        self.filesWidth = filesWidth
        self.outlineWidth = outlineWidth
        self.showFiles = showFiles
        self.showOutline = showOutline
    }

    public static let defaults = AppSettings(
        openFoldersInNewWindow: false,
        autoRefreshSingleFile: true,
        restoreLastWindow: false,
        filesWidth: 220,
        outlineWidth: 180,
        showFiles: true,
        showOutline: true
    )
}

public enum SettingsStore {
    private static let keys = (
        openFoldersInNewWindow: "openFoldersInNewWindow",
        autoRefreshSingleFile: "autoRefreshSingleFile",
        restoreLastWindow: "restoreLastWindow",
        filesWidth: "filesWidth",
        outlineWidth: "outlineWidth",
        showFiles: "showFiles",
        showOutline: "showOutline"
    )

    public static func load(defaults: UserDefaults = .standard) -> AppSettings {
        let fallback = AppSettings.defaults
        return AppSettings(
            openFoldersInNewWindow: defaults.object(forKey: keys.openFoldersInNewWindow) as? Bool ?? fallback.openFoldersInNewWindow,
            autoRefreshSingleFile: defaults.object(forKey: keys.autoRefreshSingleFile) as? Bool ?? fallback.autoRefreshSingleFile,
            restoreLastWindow: defaults.object(forKey: keys.restoreLastWindow) as? Bool ?? fallback.restoreLastWindow,
            filesWidth: defaults.object(forKey: keys.filesWidth) as? Double ?? fallback.filesWidth,
            outlineWidth: defaults.object(forKey: keys.outlineWidth) as? Double ?? fallback.outlineWidth,
            showFiles: defaults.object(forKey: keys.showFiles) as? Bool ?? fallback.showFiles,
            showOutline: defaults.object(forKey: keys.showOutline) as? Bool ?? fallback.showOutline
        )
    }

    public static func save(_ settings: AppSettings, defaults: UserDefaults = .standard) {
        defaults.set(settings.openFoldersInNewWindow, forKey: keys.openFoldersInNewWindow)
        defaults.set(settings.autoRefreshSingleFile, forKey: keys.autoRefreshSingleFile)
        defaults.set(settings.restoreLastWindow, forKey: keys.restoreLastWindow)
        defaults.set(settings.filesWidth, forKey: keys.filesWidth)
        defaults.set(settings.outlineWidth, forKey: keys.outlineWidth)
        defaults.set(settings.showFiles, forKey: keys.showFiles)
        defaults.set(settings.showOutline, forKey: keys.showOutline)
    }
}
```

Replace `native/Sources/MdreviewApp/SettingsWindowController.swift` with:

```swift
import AppKit
import MdreviewCore

final class SettingsWindowController: NSWindowController {
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func buildContent() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView?.addSubview(stack)
        [openFolders, autoRefresh, restoreWindow, widthRow(label: "文件栏默认宽度", field: filesWidth), widthRow(label: "大纲栏默认宽度", field: outlineWidth), showFiles, showOutline].forEach {
            stack.addArrangedSubview($0)
        }
        [openFolders, autoRefresh, restoreWindow, showFiles, showOutline].forEach {
            $0.target = self
            $0.action = #selector(save)
        }
        [filesWidth, outlineWidth].forEach {
            $0.target = self
            $0.action = #selector(save)
            $0.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }
        if let content = window?.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor)
            ])
        }
    }

    private func widthRow(label: String, field: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.addArrangedSubview(NSTextField(labelWithString: label))
        row.addArrangedSubview(field)
        return row
    }

    private func apply(_ settings: AppSettings) {
        openFolders.state = settings.openFoldersInNewWindow ? .on : .off
        autoRefresh.state = settings.autoRefreshSingleFile ? .on : .off
        restoreWindow.state = settings.restoreLastWindow ? .on : .off
        showFiles.state = settings.showFiles ? .on : .off
        showOutline.state = settings.showOutline ? .on : .off
        filesWidth.stringValue = String(Int(settings.filesWidth))
        outlineWidth.stringValue = String(Int(settings.outlineWidth))
    }

    @objc private func save() {
        settings = AppSettings(
            openFoldersInNewWindow: openFolders.state == .on,
            autoRefreshSingleFile: autoRefresh.state == .on,
            restoreLastWindow: restoreWindow.state == .on,
            filesWidth: Double(filesWidth.stringValue) ?? AppSettings.defaults.filesWidth,
            outlineWidth: Double(outlineWidth.stringValue) ?? AppSettings.defaults.outlineWidth,
            showFiles: showFiles.state == .on,
            showOutline: showOutline.state == .on
        )
        SettingsStore.save(settings)
    }
}
```

- [ ] **Step 4: Verify native UI state tests and build**

Run:

```bash
swift test --package-path native --filter SettingsTests
swift build --package-path native
```

Expected:

```text
SettingsTests ... passed
Build complete
```

- [ ] **Step 5: Commit workspace UI**

```bash
git add native/Sources/MdreviewApp native/Sources/MdreviewCore native/Tests/MdreviewCoreTests
git commit -m "feat: add native workspace navigation UI"
```

### Task 9: File Watching and Document Refresh

**Files:**
- Create: `native/Sources/MdreviewCore/FileWatcher.swift`
- Create: `native/Tests/MdreviewCoreTests/FileWatcherTests.swift`
- Modify: `native/Sources/MdreviewApp/MainWindowController.swift`

- [ ] **Step 1: Write failing watcher test**

Create `native/Tests/MdreviewCoreTests/FileWatcherTests.swift`:

```swift
import Foundation
import XCTest
@testable import MdreviewCore

final class FileWatcherTests: XCTestCase {
    func testWatcherReportsChange() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-watch-\(UUID().uuidString).md")
        try "# One".write(to: file, atomically: true, encoding: .utf8)
        let expectation = expectation(description: "file changed")
        let watcher = try FileWatcher(url: file) {
            expectation.fulfill()
        }
        watcher.start()
        try "# Two".write(to: file, atomically: true, encoding: .utf8)
        wait(for: [expectation], timeout: 2)
        watcher.stop()
    }
}
```

- [ ] **Step 2: Implement DispatchSource watcher**

Create `native/Sources/MdreviewCore/FileWatcher.swift`:

```swift
import Darwin
import Foundation

public final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var descriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    public init(url: URL, onChange: @escaping () -> Void) throws {
        self.url = url
        self.onChange = onChange
    }

    public func start() {
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .main)
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }
        self.source = source
        source.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}
```

- [ ] **Step 3: Wire watcher into active tabs**

Add this property to `MainWindowController`:

```swift
private var activeWatcher: FileWatcher?
private var settings = SettingsStore.load()
```

Call this at the end of `apply(windowModel:)`:

```swift
watch(activeTab: active, workspaceRoot: windowModel.workspaceRoot)
```

Add this helper to `MainWindowController`:

```swift
private func watch(activeTab: DocumentTab?, workspaceRoot: URL?) {
    activeWatcher?.stop()
    activeWatcher = nil
    guard settings.autoRefreshSingleFile, let activeTab else { return }
    activeWatcher = try? FileWatcher(url: activeTab.url) { [weak self, activeTab, workspaceRoot] in
        DispatchQueue.main.async {
            self?.render(tab: activeTab, workspaceRoot: workspaceRoot)
        }
    }
    activeWatcher?.start()
}
```

- [ ] **Step 4: Verify watcher**

Run:

```bash
swift test --package-path native --filter FileWatcherTests
swift build --package-path native
```

Expected:

```text
FileWatcherTests ... passed
Build complete
```

- [ ] **Step 5: Commit watcher**

```bash
git add native/Sources/MdreviewCore native/Sources/MdreviewApp native/Tests/MdreviewCoreTests
git commit -m "feat: add native file refresh"
```

### Task 10: App Bundle Packaging and Documentation

**Files:**
- Create: `scripts/package-macos-app.mjs`
- Create: `native/Info.plist`
- Modify: `package.json`
- Modify: `README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Register package script and verify missing bundler failure**

Add this script entry to `package.json` before creating `scripts/package-macos-app.mjs`:

```json
{
  "build:app": "npm run build:web && swift build --package-path native && node scripts/package-macos-app.mjs"
}
```

Run:

```bash
npm run build:app
```

Expected:

```text
Cannot find module './scripts/package-macos-app.mjs'
```

- [ ] **Step 2: Implement app bundler**

Create `native/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>mdreview</string>
  <key>CFBundleDisplayName</key>
  <string>mdreview</string>
  <key>CFBundleIdentifier</key>
  <string>dev.mdreview.app</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleExecutable</key>
  <string>mdreview-app</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
</dict>
</plist>
```

Create `scripts/package-macos-app.mjs`:

```js
import { mkdir, cp, copyFile, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const appRoot = path.join(root, "native", "dist", "mdreview.app");
const contents = path.join(appRoot, "Contents");
const macos = path.join(contents, "MacOS");
const resources = path.join(contents, "Resources");

await rm(appRoot, { recursive: true, force: true });
await mkdir(macos, { recursive: true });
await mkdir(resources, { recursive: true });
await copyFile(path.join(root, "native", "Info.plist"), path.join(contents, "Info.plist"));
await copyFile(path.join(root, "native", ".build", "debug", "mdreview-app"), path.join(macos, "mdreview-app"));
await cp(path.join(root, "dist", "client"), path.join(resources, "renderer"), { recursive: true });
console.log(`已创建 ${appRoot}`);
```

Update `package.json` scripts:

```json
{
  "build:app": "npm run build:web && swift build --package-path native && node scripts/package-macos-app.mjs",
  "test:all": "npm run typecheck && npm test && npm run test:native"
}
```

- [ ] **Step 3: Update README native usage**

Replace browser-first usage with:

~~~markdown
## Usage

```bash
npm run build:app
node dist/node/index.js README.md
node dist/node/index.js docs
node dist/node/index.js docs --new-window
```

`mdreview` 是 macOS 原生 App。命令行入口会自动启动 App，并把文件或目录打开请求交给正在运行的 App。

单文件模式隐藏文件栏，只显示大纲和正文。目录模式显示左侧文件栏、大纲和正文。
~~~

- [ ] **Step 4: Verify packaging**

Run:

```bash
npm run build:app
test -d native/dist/mdreview.app
test -f native/dist/mdreview.app/Contents/MacOS/mdreview-app
test -d native/dist/mdreview.app/Contents/Resources/renderer
```

Expected:

```text
已创建 .../native/dist/mdreview.app
```

- [ ] **Step 5: Commit packaging**

```bash
git add package.json README.md scripts native/Info.plist .gitignore
git commit -m "chore: package native mac app"
```

### Task 11: Final Verification and Manual Smoke

**Files:**
- No planned file changes. If a verification command fails, use `superpowers:systematic-debugging` before editing files, then commit the focused fix.

- [ ] **Step 1: Run full automated verification**

Run:

```bash
npm run typecheck
npm test
npm run test:native
npm run build
npm run build:app
```

Expected:

```text
No TypeScript errors.
All Vitest tests pass.
All Swift tests pass.
Vite and tsup build complete.
native/dist/mdreview.app exists.
```

- [ ] **Step 2: Run CLI smoke against the packaged app**

Run:

```bash
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js README.md
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js tests/fixtures/docs --new-window
```

Expected:

```text
已打开
```

If AppKit cannot display in the current automation environment, run the command locally on macOS desktop and record the result in the final message.

- [ ] **Step 3: Run manual UI acceptance**

On macOS desktop:

```bash
open native/dist/mdreview.app
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js README.md
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js tests/fixtures/docs
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js tests/fixtures/docs --new-window
```

Verify:

```text
菜单为中文。
单文件窗口不显示文件栏。
目录窗口显示文件栏 + 大纲 + 正文。
打开同一文件聚焦已有标签页。
打开目录默认替换当前窗口 workspace。
--new-window 创建新窗口。
界面清爽，接近 GitBook 文档阅读风格。
```

- [ ] **Step 4: Commit verification fixes**

If any verification fix changed files:

```bash
git add .
git commit -m "chore: verify native app migration"
```

If no files changed, do not create an empty commit.

## Final Acceptance Checklist

- [ ] `mdreview.app` can be built without Xcode project files using SwiftPM and `scripts/package-macos-app.mjs`.
- [ ] `mdreview <file>` starts or contacts the App and opens a document tab.
- [ ] Reopening the same file focuses the existing tab.
- [ ] `mdreview <directory>` reuses the current window, clears old tabs, and opens the default document.
- [ ] `mdreview <directory> --new-window` creates a new workspace window.
- [ ] Single-file windows hide the file column and show only outline + document.
- [ ] Directory windows show file column + outline + document.
- [ ] Menus, settings, CLI help, CLI errors, and empty states are Chinese by default.
- [ ] Renderer still supports safe Markdown, GFM, code highlight, Mermaid, and math.
- [ ] Local relative resources load through `mdreview-resource://` with realpath containment.
- [ ] `npm run typecheck`, `npm test`, `npm run test:native`, `npm run build`, and `npm run build:app` pass.
