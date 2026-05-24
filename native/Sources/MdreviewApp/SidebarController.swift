import AppKit
import MdreviewCore

@MainActor
final class SidebarController {
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
        filesContainer.isHidden = layoutMode == .outlineAndDocument
        if layoutMode == .outlineAndDocument {
            filesContainer.setCollapsed(false)
        }
    }

    func renderFiles(nodes: [MarkdownNode], activePath: String?) {
        clear(filesStack)
        if nodes.isEmpty {
            filesStack.addArrangedSubview(sidebarLabel("没有 Markdown 文件"))
        } else {
            addFiles(nodes, depth: 0, activePath: activePath)
        }
        filesView.needsLayout = true
    }

    private func addFiles(_ nodes: [MarkdownNode], depth: Int, activePath: String?) {
        for node in nodes {
            if node.type == .directory {
                let label = sidebarLabel(node.name, identifier: "directory:\(node.path)", depth: depth)
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

    func renderOutline(_ items: [NativeOutlineItem]) {
        outlineItems = items
        activeHeadingID = nil
        reloadOutlineRows()
    }

    private func reloadOutlineRows() {
        clear(outlineStack)
        if outlineItems.isEmpty {
            outlineStack.addArrangedSubview(sidebarLabel("没有大纲"))
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

    func toggleFiles() {
        setFilesCollapsed(!filesContainer.isCollapsed)
    }

    func toggleOutline() {
        setOutlineCollapsed(!outlineContainer.isCollapsed)
    }

    func setFilesCollapsed(_ collapsed: Bool) {
        filesContainer.setCollapsed(collapsed)
    }

    func setOutlineCollapsed(_ collapsed: Bool) {
        outlineContainer.setCollapsed(collapsed)
    }

    @objc private func expandFilesFromRail() {
        onExpandFiles?()
    }

    @objc private func expandOutlineFromRail() {
        onExpandOutline?()
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

    private func sidebarLabel(_ title: String, identifier: String? = nil, depth: Int = 0) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.identifier = identifier.map { NSUserInterfaceItemIdentifier($0) }
        label.tag = depth
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        paragraphStyle.firstLineHeadIndent = CGFloat(depth * 14)
        paragraphStyle.headIndent = CGFloat(depth * 14)
        label.attributedStringValue = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        return label
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

@MainActor
final class SidebarPaneView: NSView {
    static let collapsedWidth: CGFloat = 28

    private let contentView: NSView
    private let railView = NSView()
    private let expandButton = NSButton()
    private let expandAccessibilityLabel: String
    private(set) var isCollapsed = false

    init(contentView: NSView, expandAccessibilityLabel: String, target: AnyObject?, action: Selector) {
        self.contentView = contentView
        self.expandAccessibilityLabel = expandAccessibilityLabel
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
        expandButton.setAccessibilityLabel(collapsed ? expandAccessibilityLabel : nil)
        expandButton.toolTip = collapsed ? expandAccessibilityLabel : nil
        needsLayout = true
    }
}
