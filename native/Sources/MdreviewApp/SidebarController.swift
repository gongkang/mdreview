import AppKit
import MdreviewCore

@MainActor
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
