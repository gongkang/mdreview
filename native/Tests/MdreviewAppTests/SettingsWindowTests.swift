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
        parent.isReleasedWhenClosed = false
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
