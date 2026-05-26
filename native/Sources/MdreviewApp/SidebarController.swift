import AppKit
import MdreviewCore

@MainActor
final class SidebarController {
    private enum TreeMetrics {
        static let indentUnit: CGFloat = 14
        static let maximumIndent: CGFloat = 84
    }

    let filesView: NSScrollView = SidebarScrollView()
    let outlineView: NSScrollView = SidebarScrollView()
    let fileEdgeTriggerView = FileEdgeTriggerView()
    let fileDrawerView = FileDirectoryChromeView()
    private(set) lazy var filesContainer = FileDirectoryPaneView(edgeView: fileEdgeTriggerView)
    private(set) lazy var outlineContainer = SidebarPaneView(
        contentView: outlineView,
        backgroundColor: .white,
        contentInsets: NSEdgeInsets(top: 12, left: 16, bottom: 0, right: 12)
    )
    private let filesStack = SidebarStackView()
    private let outlineStack = SidebarStackView()
    private var outlineItems = [NativeOutlineItem]()
    private var activeHeadingID: String?
    private var expandedFileDirectoryPaths = Set<String>()
    private var lastFileTree = [MarkdownNode]()
    private var lastActiveFilePath: String?
    private var knownFileDirectoryPaths = Set<String>()
    var onSelectFile: ((String) -> Void)?
    var onSelectHeading: ((String) -> Void)?

    init() {
        configure(filesView, stack: filesStack)
        configure(outlineView, stack: outlineStack)
        showFileEdgeTrigger()
        showFileDrawer(false)
    }

    private func configure(_ scrollView: NSScrollView, stack: NSStackView) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        scrollView.documentView = stack
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.contentView.drawsBackground = false
    }

    func apply(layoutMode: LayoutMode) {
        switch layoutMode {
        case .filesOutlineAndDocument:
            filesContainer.isHidden = false
        case .outlineAndDocument:
            filesContainer.isHidden = true
            showFileDrawer(false)
        }
    }

    func renderFiles(nodes: [MarkdownNode], activePath: String?) {
        let nextDirectoryPaths = directoryPaths(in: nodes)
        if nextDirectoryPaths != knownFileDirectoryPaths {
            expandedFileDirectoryPaths.formIntersection(nextDirectoryPaths)
            knownFileDirectoryPaths = nextDirectoryPaths
        }
        if activePath != lastActiveFilePath {
            expandedFileDirectoryPaths.formUnion(ancestorDirectoryPaths(for: activePath))
        }
        lastFileTree = nodes
        lastActiveFilePath = activePath
        reloadFileRows()
    }

    private func reloadFileRows() {
        clear(filesStack)
        if lastFileTree.isEmpty {
            filesStack.addArrangedSubview(sidebarLabel("没有 Markdown 文件"))
        } else {
            addFiles(lastFileTree, depth: 0, activePath: lastActiveFilePath)
        }
        filesView.needsLayout = true
    }

    private func addFiles(_ nodes: [MarkdownNode], depth: Int, activePath: String?) {
        for node in nodes {
            if node.type == .directory {
                let isExpanded = expandedFileDirectoryPaths.contains(node.path)
                let row = SidebarDirectoryRowButton(
                    title: node.name,
                    identifier: "directory:\(node.path)",
                    depth: depth,
                    isExpanded: isExpanded,
                    target: self,
                    action: #selector(toggleDirectory(_:))
                )
                filesStack.addArrangedSubview(row)
                if isExpanded {
                    addFiles(node.children, depth: depth + 1, activePath: activePath)
                }
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
        showFileEdgeTrigger()
    }

    func setOutlineCollapsed(_ collapsed: Bool) {
        outlineContainer.setCollapsed(collapsed)
    }

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
        unpin: @escaping () -> Void,
        drawerMouseExit: @escaping () -> Void
    ) {
        fileEdgeTriggerView.onOpen = open
        fileDrawerView.onPin = pin
        filesContainer.onUnpin = unpin
        fileDrawerView.onMouseExit = drawerMouseExit
    }

    @objc private func selectFile(_ sender: SidebarRowButton) {
        guard let path = sender.identifier?.rawValue else { return }
        onSelectFile?(path)
    }

    @objc private func toggleDirectory(_ sender: SidebarDirectoryRowButton) {
        guard let rawIdentifier = sender.identifier?.rawValue,
              rawIdentifier.hasPrefix("directory:")
        else { return }
        let path = String(rawIdentifier.dropFirst("directory:".count))
        if expandedFileDirectoryPaths.contains(path) {
            expandedFileDirectoryPaths.remove(path)
        } else {
            expandedFileDirectoryPaths.insert(path)
        }
        reloadFileRows()
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
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.toolTip = title
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let visualIndent = min(CGFloat(depth) * TreeMetrics.indentUnit, TreeMetrics.maximumIndent)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.firstLineHeadIndent = visualIndent
        paragraphStyle.headIndent = visualIndent
        label.attributedStringValue = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
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

    private func directoryPaths(in nodes: [MarkdownNode]) -> Set<String> {
        var paths = Set<String>()
        for node in nodes where node.type == .directory {
            paths.insert(node.path)
            paths.formUnion(directoryPaths(in: node.children))
        }
        return paths
    }

    private func ancestorDirectoryPaths(for activePath: String?) -> Set<String> {
        guard let activePath else { return [] }
        let parts = activePath.split(separator: "/").map(String.init)
        guard parts.count > 1 else { return [] }
        return Set((1..<parts.count).map { parts.prefix($0).joined(separator: "/") })
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
            width: contentView.bounds.width,
            height: max(contentView.bounds.height, fittingSize.height)
        )
        stack.layoutSubtreeIfNeeded()
    }
}

@MainActor
final class FileEdgeTriggerView: NSView {
    let button = NSButton()
    var onOpen: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet {
            updateAppearance()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.controlSize = .mini
        button.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "打开文件列表")
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.setAccessibilityLabel("打开文件列表")
        button.toolTip = "打开文件列表"
        button.target = self
        button.action = #selector(open)
        addSubview(button)
        updateAppearance()

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 22),
            button.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let next = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(next)
        trackingArea = next
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        onOpen?()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    @objc private func open() {
        onOpen?()
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(isHovered ? 0.05 : 0.0).cgColor
        button.alphaValue = isHovered ? 0.82 : 0.34
    }
}

@MainActor
final class FileDirectoryChromeView: NSView {
    let pinButton = NSButton()
    private let titleLabel = NSTextField(labelWithString: "文件")
    private let contentSlot = NSView()
    private var hostedContent: NSView?
    private var hostedConstraints = [NSLayoutConstraint]()
    private var trackingArea: NSTrackingArea?
    var onPin: (() -> Void)?
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
        actions.addArrangedSubview(pinButton)

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
        NSLayoutConstraint.deactivate(hostedConstraints)
        hostedConstraints.removeAll()
        hostedContent?.removeFromSuperview()
        hostedContent = view
        view.translatesAutoresizingMaskIntoConstraints = false
        contentSlot.addSubview(view)
        hostedConstraints = [
            view.leadingAnchor.constraint(equalTo: contentSlot.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentSlot.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentSlot.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentSlot.bottomAnchor)
        ]
        NSLayoutConstraint.activate(hostedConstraints)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let next = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(next)
        trackingArea = next
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

    @objc private func pin() {
        onPin?()
    }
}

@MainActor
final class FileDirectoryPaneView: NSView {
    private enum Metrics {
        static let edgeWidth: CGFloat = 28
    }

    enum Mode {
        case edge
        case pinned
    }

    private let edgeView: FileEdgeTriggerView
    private let titleLabel = NSTextField(labelWithString: "文件")
    private let unpinButton = NSButton()
    private let pinnedHeader = NSView()
    private let contentSlot = NSView()
    private let trailingSeparator = NSView()
    private var hostedContent: NSView?
    private var hostedConstraints = [NSLayoutConstraint]()
    private var edgeWidthConstraint: NSLayoutConstraint?
    private(set) var mode: Mode = .edge
    var onUnpin: (() -> Void)?

    var isCollapsed: Bool {
        mode == .edge
    }

    init(edgeView: FileEdgeTriggerView) {
        self.edgeView = edgeView
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        edgeView.translatesAutoresizingMaskIntoConstraints = false
        pinnedHeader.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        unpinButton.translatesAutoresizingMaskIntoConstraints = false
        contentSlot.translatesAutoresizingMaskIntoConstraints = false
        trailingSeparator.translatesAutoresizingMaskIntoConstraints = false
        trailingSeparator.identifier = NSUserInterfaceItemIdentifier("file-directory-trailing-separator")
        trailingSeparator.wantsLayer = true
        trailingSeparator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.18).cgColor
        addSubview(edgeView)
        addSubview(pinnedHeader)
        addSubview(contentSlot)
        addSubview(trailingSeparator)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        configure(unpinButton, symbol: "pin.slash", label: "取消固定文件列表", action: #selector(unpin))
        pinnedHeader.addSubview(titleLabel)
        pinnedHeader.addSubview(unpinButton)
        NSLayoutConstraint.activate([
            edgeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            edgeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            edgeView.topAnchor.constraint(equalTo: topAnchor),
            edgeView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pinnedHeader.leadingAnchor.constraint(equalTo: leadingAnchor),
            pinnedHeader.trailingAnchor.constraint(equalTo: trailingAnchor),
            pinnedHeader.topAnchor.constraint(equalTo: topAnchor),
            pinnedHeader.heightAnchor.constraint(equalToConstant: 46),
            titleLabel.leadingAnchor.constraint(equalTo: pinnedHeader.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: pinnedHeader.centerYAnchor),
            unpinButton.trailingAnchor.constraint(equalTo: pinnedHeader.trailingAnchor, constant: -12),
            unpinButton.centerYAnchor.constraint(equalTo: pinnedHeader.centerYAnchor),
            contentSlot.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentSlot.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentSlot.topAnchor.constraint(equalTo: topAnchor, constant: 46),
            contentSlot.bottomAnchor.constraint(equalTo: bottomAnchor),
            trailingSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            trailingSeparator.topAnchor.constraint(equalTo: topAnchor),
            trailingSeparator.bottomAnchor.constraint(equalTo: bottomAnchor),
            trailingSeparator.widthAnchor.constraint(equalToConstant: 1)
        ])
        edgeWidthConstraint = widthAnchor.constraint(equalToConstant: Metrics.edgeWidth)
        setMode(.edge)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func host(_ view: NSView) {
        NSLayoutConstraint.deactivate(hostedConstraints)
        hostedConstraints.removeAll()
        hostedContent?.removeFromSuperview()
        hostedContent = view
        view.translatesAutoresizingMaskIntoConstraints = false
        contentSlot.addSubview(view)
        hostedConstraints = [
            view.leadingAnchor.constraint(equalTo: contentSlot.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentSlot.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentSlot.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentSlot.bottomAnchor)
        ]
        NSLayoutConstraint.activate(hostedConstraints)
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
        layer?.backgroundColor = (mode == .pinned ? NSColor.white : NSColor.clear).cgColor
        edgeView.isHidden = mode != .edge
        pinnedHeader.isHidden = mode != .pinned
        contentSlot.isHidden = mode != .pinned
        trailingSeparator.isHidden = mode != .pinned
        edgeWidthConstraint?.isActive = mode == .edge
    }

    private func configure(_ button: NSButton, symbol: String, label: String, action: Selector) {
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

    @objc private func unpin() {
        onUnpin?()
    }
}

@MainActor
final class SidebarPaneView: NSView {
    static let collapsedWidth: CGFloat = 28

    private let contentView: NSView
    private let railView = NSView()
    private(set) var isCollapsed = false
    private let maxContentWidth: CGFloat?
    private let contentInsets: NSEdgeInsets

    init(
        contentView: NSView,
        backgroundColor: NSColor? = nil,
        maxContentWidth: CGFloat? = nil,
        contentInsets: NSEdgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    ) {
        self.contentView = contentView
        self.maxContentWidth = maxContentWidth
        self.contentInsets = contentInsets
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = backgroundColor?.cgColor

        contentView.translatesAutoresizingMaskIntoConstraints = true
        railView.translatesAutoresizingMaskIntoConstraints = true
        railView.wantsLayer = true

        addSubview(contentView)
        addSubview(railView)

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

    override func layout() {
        super.layout()
        railView.frame = bounds
        let availableWidth = max(0, bounds.width - contentInsets.left - contentInsets.right)
        let contentWidth = maxContentWidth.map { min(availableWidth, $0) } ?? availableWidth
        contentView.frame = NSRect(
            x: contentInsets.left,
            y: contentInsets.bottom,
            width: contentWidth,
            height: max(0, bounds.height - contentInsets.top - contentInsets.bottom)
        )
    }
}
