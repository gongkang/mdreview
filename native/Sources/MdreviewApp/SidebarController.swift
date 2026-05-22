import AppKit
import MdreviewCore

@MainActor
final class SidebarController {
    let filesView = NSScrollView()
    let outlineView = NSScrollView()
    private let filesStack = NSStackView()
    private let outlineStack = NSStackView()
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
            return
        }
        addFiles(nodes, depth: 0, activePath: activePath)
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
            return
        }
        for item in items {
            let title = String(repeating: "  ", count: max(0, item.depth - 1)) + item.text
            let button = NSButton(title: title, target: self, action: #selector(selectHeading(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(item.id)
            button.bezelStyle = .texturedRounded
            outlineStack.addArrangedSubview(button)
        }
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
