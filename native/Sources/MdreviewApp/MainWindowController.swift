import AppKit
import MdreviewCore

final class MainWindowController: NSWindowController {
    private let splitView = NSSplitView()
    private lazy var fileDividerButton = makeDividerButton(action: #selector(toggleFilesFromDivider))
    private lazy var outlineDividerButton = makeDividerButton(action: #selector(toggleOutlineFromDivider))
    private let tabBar = DocumentTabBar()
    private let sidebar = SidebarController()
    private let resourceHandler = ResourceSchemeHandler()
    private lazy var renderer = RendererViewController(resourceHandler: resourceHandler)
    private var didBuildLayout = false
    var onOpenWorkspaceFile: ((URL) -> Void)?
    var onSelectTab: ((UUID) -> Void)?
    private var currentWorkspaceRoot: URL?
    private var currentWindowModel: WindowModel?
    private var activeWatcher: FileWatcher?
    private var settings: AppSettings
    private var lastAppliedLayoutMode: LayoutMode?
    private var isDeferringSplitRatioApplication = false
    private var isFilesCollapsed = false
    private var isOutlineCollapsed = false
    private var lastExpandedFilesWidth: CGFloat?
    private var lastExpandedOutlineWidth: CGFloat?
    private(set) var modelID: UUID?

    private enum SplitRatio {
        static let folderFiles: CGFloat = 0.17
        static let folderOutline: CGFloat = 0.14
        static let singleFileOutline: CGFloat = 0.16
    }

    private enum SidebarCollapse {
        static let railWidth: CGFloat = 28
    }

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

    override func windowDidLoad() {
        super.windowDidLoad()
        buildLayout()
    }

    private func buildLayout() {
        guard !didBuildLayout else { return }
        guard let root = window?.contentView else { return }
        didBuildLayout = true
        tabBar.view.translatesAutoresizingMaskIntoConstraints = false
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        root.addSubview(tabBar.view)
        root.addSubview(splitView)
        root.addSubview(fileDividerButton)
        root.addSubview(outlineDividerButton)
        NSLayoutConstraint.activate([
            tabBar.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            tabBar.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            tabBar.view.topAnchor.constraint(equalTo: root.topAnchor),
            tabBar.view.heightAnchor.constraint(equalToConstant: 34),
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: tabBar.view.bottomAnchor),
            splitView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        sidebar.filesContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebar.outlineContainer.translatesAutoresizingMaskIntoConstraints = false
        renderer.view.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(sidebar.filesContainer)
        splitView.addArrangedSubview(sidebar.outlineContainer)
        splitView.addArrangedSubview(renderer.view)
        NSLayoutConstraint.activate([
            fileDividerButton.centerXAnchor.constraint(equalTo: sidebar.filesContainer.trailingAnchor),
            fileDividerButton.centerYAnchor.constraint(equalTo: splitView.centerYAnchor),
            fileDividerButton.widthAnchor.constraint(equalToConstant: 22),
            fileDividerButton.heightAnchor.constraint(equalToConstant: 22),

            outlineDividerButton.centerXAnchor.constraint(equalTo: sidebar.outlineContainer.trailingAnchor),
            outlineDividerButton.centerYAnchor.constraint(equalTo: splitView.centerYAnchor),
            outlineDividerButton.widthAnchor.constraint(equalToConstant: 22),
            outlineDividerButton.heightAnchor.constraint(equalToConstant: 22)
        ])
        if let rendererURL = Bundle.main.resourceURL?.appendingPathComponent("renderer/index.html") {
            renderer.loadRenderer(from: rendererURL)
        }
        sidebar.onSelectFile = { [weak self] relativePath in
            guard let self, let root = self.currentWorkspaceRoot else { return }
            self.onOpenWorkspaceFile?(root.appendingPathComponent(relativePath))
        }
        sidebar.onSelectHeading = { [weak self] id in
            self?.renderer.scrollToHeading(id: id)
        }
        renderer.onOutlineChanged = { [weak self] items in
            self?.sidebar.renderOutline(items)
        }
        tabBar.onSelectTab = { [weak self] tabID in
            self?.onSelectTab?(tabID)
        }
        updateDividerControls()
    }

    private func makeDividerButton(action: Selector) -> DividerButton {
        let button = DividerButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.isHidden = true
        return button
    }

    @objc private func toggleFilesFromDivider() {
        toggleFiles()
    }

    @objc private func toggleOutlineFromDivider() {
        toggleOutline()
    }

    func apply(windowModel: WindowModel) {
        modelID = windowModel.id
        currentWindowModel = windowModel
        currentWorkspaceRoot = windowModel.workspaceRoot
        tabBar.render(tabs: windowModel.tabs, activeTabID: windowModel.activeTabID)
        let shouldApplyDefaultRatio = lastAppliedLayoutMode != windowModel.layoutMode
        lastAppliedLayoutMode = windowModel.layoutMode
        sidebar.apply(layoutMode: windowModel.layoutMode)
        if shouldApplyDefaultRatio {
            resetCollapsedState(for: windowModel.layoutMode)
        }
        let active = windowModel.tabs.first(where: { $0.id == windowModel.activeTabID })
        let activeRelativePath = active.flatMap { tab -> String? in
            guard let root = windowModel.workspaceRoot else { return nil }
            let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
            return tab.url.path.hasPrefix(prefix) ? String(tab.url.path.dropFirst(prefix.count)) : nil
        }
        sidebar.renderFiles(nodes: windowModel.fileTree, activePath: activeRelativePath)
        window?.title = active?.title ?? "mdreview"
        if let active {
            render(tab: active, workspaceRoot: windowModel.workspaceRoot)
        }
        watch(activeTab: active, workspaceRoot: windowModel.workspaceRoot)
        applyDefaultSplitRatioIfNeeded(for: windowModel.layoutMode, force: shouldApplyDefaultRatio)
        updateDividerControls(for: windowModel.layoutMode)
    }

    private func resetCollapsedState(for layoutMode: LayoutMode) {
        isFilesCollapsed = false
        isOutlineCollapsed = false
        lastExpandedFilesWidth = nil
        lastExpandedOutlineWidth = nil
        sidebar.setFilesCollapsed(false)
        sidebar.setOutlineCollapsed(false)
        if layoutMode == .outlineAndDocument {
            sidebar.filesContainer.isHidden = true
        }
        updateDividerControls(for: layoutMode)
    }

    private func updateDividerControls(for layoutMode: LayoutMode? = nil) {
        let mode = layoutMode ?? currentWindowModel?.layoutMode

        if mode == .filesOutlineAndDocument {
            fileDividerButton.isHidden = false
            configureDividerButton(
                fileDividerButton,
                collapsed: isFilesCollapsed,
                collapseLabel: "收起文件列表",
                expandLabel: "展开文件列表"
            )
        } else {
            clearDividerButton(fileDividerButton)
        }

        if mode == nil {
            clearDividerButton(outlineDividerButton)
        } else {
            outlineDividerButton.isHidden = false
            configureDividerButton(
                outlineDividerButton,
                collapsed: isOutlineCollapsed,
                collapseLabel: "收起大纲",
                expandLabel: "展开大纲"
            )
        }
    }

    private func configureDividerButton(_ button: DividerButton, collapsed: Bool, collapseLabel: String, expandLabel: String) {
        let label = collapsed ? expandLabel : collapseLabel
        let symbolName = collapsed ? "chevron.right" : "chevron.left"
        button.setSymbolName(symbolName)
        button.setAccessibilityLabel(label)
        button.toolTip = label
    }

    private func clearDividerButton(_ button: DividerButton) {
        button.isHidden = true
        button.clearSymbol()
        button.setAccessibilityLabel(nil)
        button.toolTip = nil
    }

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
            sidebar.filesContainer.isHidden = false
            splitView.setPosition(totalWidth * SplitRatio.folderFiles, ofDividerAt: 0)
            splitView.setPosition(totalWidth * (SplitRatio.folderFiles + SplitRatio.folderOutline), ofDividerAt: 1)
            splitView.setPosition(totalWidth * SplitRatio.folderFiles, ofDividerAt: 0)
        case .outlineAndDocument:
            sidebar.filesContainer.isHidden = true
            splitView.setPosition(0, ofDividerAt: 0)
            splitView.setPosition(totalWidth * SplitRatio.singleFileOutline, ofDividerAt: 1)
        }

        splitView.layoutSubtreeIfNeeded()
    }

    private func render(tab: DocumentTab, workspaceRoot: URL?) {
        resourceHandler.root = workspaceRoot ?? tab.url.deletingLastPathComponent()
        resourceHandler.currentDocument = tab.url
        do {
            let content = try String(contentsOf: tab.url, encoding: .utf8)
            sidebar.renderOutline(MarkdownOutline.parse(content))
            renderer.render(path: tab.url.path, name: tab.title, content: content, scrollPosition: tab.scrollPosition)
        } catch {
            let message = "文件不存在：\(tab.url.path)"
            sidebar.renderOutline(MarkdownOutline.parse(message))
            renderer.render(path: tab.url.path, name: tab.title, content: message, scrollPosition: tab.scrollPosition)
        }
    }

    func toggleFiles() {
        guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
        if isFilesCollapsed {
            expandFiles()
        } else {
            collapseFiles()
        }
    }

    func toggleOutline() {
        if isOutlineCollapsed {
            expandOutline()
        } else {
            collapseOutline()
        }
    }

    private func collapseFiles() {
        guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
        guard !isFilesCollapsed else { return }
        splitView.layoutSubtreeIfNeeded()
        let currentWidth = splitView.subviews[0].frame.width
        if currentWidth > SidebarCollapse.railWidth {
            lastExpandedFilesWidth = currentWidth
        }
        isFilesCollapsed = true
        sidebar.setFilesCollapsed(true)
        updateDividerControls()
        splitView.setPosition(SidebarCollapse.railWidth, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
    }

    private func expandFiles() {
        guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
        guard isFilesCollapsed else { return }
        splitView.layoutSubtreeIfNeeded()
        let targetWidth = lastExpandedFilesWidth ?? splitView.bounds.width * SplitRatio.folderFiles
        isFilesCollapsed = false
        sidebar.setFilesCollapsed(false)
        updateDividerControls()
        splitView.setPosition(targetWidth, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
    }

    private func collapseOutline() {
        guard !isOutlineCollapsed else { return }
        splitView.layoutSubtreeIfNeeded()
        let currentWidth = splitView.subviews[1].frame.width
        if currentWidth > SidebarCollapse.railWidth {
            lastExpandedOutlineWidth = currentWidth + splitView.dividerThickness
        }
        isOutlineCollapsed = true
        sidebar.setOutlineCollapsed(true)
        updateDividerControls()
        setOutlineWidth(SidebarCollapse.railWidth)
    }

    private func expandOutline() {
        guard isOutlineCollapsed else { return }
        splitView.layoutSubtreeIfNeeded()
        let targetWidth: CGFloat
        if let lastExpandedOutlineWidth {
            targetWidth = lastExpandedOutlineWidth
        } else if currentWindowModel?.layoutMode == .filesOutlineAndDocument {
            targetWidth = splitView.bounds.width * SplitRatio.folderOutline
        } else {
            targetWidth = splitView.bounds.width * SplitRatio.singleFileOutline
        }
        isOutlineCollapsed = false
        sidebar.setOutlineCollapsed(false)
        updateDividerControls()
        setOutlineWidth(targetWidth)
    }

    private func setOutlineWidth(_ outlineWidth: CGFloat) {
        splitView.layoutSubtreeIfNeeded()
        let adjustedOutlineWidth = outlineWidth + splitView.dividerThickness
        if currentWindowModel?.layoutMode == .outlineAndDocument {
            sidebar.filesContainer.isHidden = true
            splitView.setPosition(0, ofDividerAt: 0)
            splitView.setPosition(adjustedOutlineWidth, ofDividerAt: 1)
        } else {
            let filesWidth = splitView.subviews[0].frame.width
            splitView.setPosition(filesWidth + adjustedOutlineWidth, ofDividerAt: 1)
        }
        splitView.layoutSubtreeIfNeeded()
    }

    func reloadDocument() {
        guard let windowModel = currentWindowModel,
              let active = windowModel.tabs.first(where: { $0.id == windowModel.activeTabID }) else { return }
        render(tab: active, workspaceRoot: windowModel.workspaceRoot)
    }

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
}

private final class DividerButton: NSButton {
    private let symbolView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setSymbolName(_ symbolName: String) {
        symbolView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    func clearSymbol() {
        symbolView.image = nil
    }

    private func configure() {
        title = ""
        setButtonType(.momentaryChange)
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.contentTintColor = .secondaryLabelColor
        symbolView.imageScaling = .scaleProportionallyDown
        addSubview(symbolView)
        NSLayoutConstraint.activate([
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 8),
            symbolView.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
}
