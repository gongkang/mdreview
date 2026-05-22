import AppKit
import MdreviewCore

@MainActor
final class SidebarController {
    let filesView: NSScrollView = SidebarScrollView()
    let outlineView: NSScrollView = SidebarScrollView()
    private let filesStack = SidebarStackView()
    private let outlineStack = SidebarStackView()
    var onSelectFile: ((String) -> Void)?
    var onSelectHeading: ((String) -> Void)?

    init() {
        configure(filesView, stack: filesStack)
        configure(outlineView, stack: outlineStack)
    }

    private func configure(_ scrollView: NSScrollView, stack: NSStackView) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        scrollView.documentView = stack
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
    }

    func apply(layoutMode: LayoutMode) {
        filesView.isHidden = layoutMode == .outlineAndDocument
    }

    func renderFiles(nodes: [MarkdownNode], activePath: String?) {
        clear(filesStack)
        if nodes.isEmpty {
            filesStack.addArrangedSubview(NSTextField(labelWithString: "没有 Markdown 文件"))
        } else {
            addFiles(nodes, depth: 0, activePath: activePath)
        }
        filesView.needsLayout = true
    }

    private func addFiles(_ nodes: [MarkdownNode], depth: Int, activePath: String?) {
        for node in nodes {
            if node.type == .directory {
                let label = NSTextField(labelWithString: String(repeating: "  ", count: depth) + node.name)
                filesStack.addArrangedSubview(label)
                addFiles(node.children, depth: depth + 1, activePath: activePath)
            } else {
                let button = NSButton(title: String(repeating: "  ", count: depth) + node.name, target: self, action: #selector(selectFile(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(node.path)
                button.bezelStyle = node.path == activePath ? .rounded : .texturedRounded
                filesStack.addArrangedSubview(button)
            }
        }
    }

    func renderOutline(_ items: [NativeOutlineItem]) {
        clear(outlineStack)
        if items.isEmpty {
            outlineStack.addArrangedSubview(NSTextField(labelWithString: "没有大纲"))
        } else {
            for item in items {
                let title = String(repeating: "  ", count: max(0, item.depth - 1)) + item.text
                let button = NSButton(title: title, target: self, action: #selector(selectHeading(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(item.id)
                button.bezelStyle = .texturedRounded
                outlineStack.addArrangedSubview(button)
            }
        }
        outlineView.needsLayout = true
    }

    func toggleFiles() {
        filesView.isHidden.toggle()
    }

    func toggleOutline() {
        outlineView.isHidden.toggle()
    }

    @objc private func selectFile(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        onSelectFile?(path)
    }

    @objc private func selectHeading(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        onSelectHeading?(id)
    }

    private func clear(_ stack: NSStackView) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}

private final class SidebarStackView: NSStackView {
    override var isFlipped: Bool {
        true
    }
}

private final class SidebarScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let stack = documentView as? NSStackView else { return }
        stack.layoutSubtreeIfNeeded()
        let fittingSize = stack.fittingSize
        stack.frame = NSRect(
            x: 0,
            y: 0,
            width: max(contentView.bounds.width, fittingSize.width),
            height: max(contentView.bounds.height, fittingSize.height)
        )
        stack.layoutSubtreeIfNeeded()
    }
}
