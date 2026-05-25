import AppKit
import MdreviewCore

enum FileDirectoryMode: Equatable {
    case edgeCollapsed
    case hoverOpen
    case pinned
}

final class MainWindowController: NSWindowController {
    private let splitView = ReaderSplitView()
    private lazy var outlineToggleButton = makeNavigationIconButton(
        symbolName: "list.bullet",
        action: #selector(toggleOutlineFromNavigationButton)
    )
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
    private var fileDirectoryMode: FileDirectoryMode = .edgeCollapsed
    private var isOutlineVisible = true
    private var lastPinnedFilesWidth: CGFloat?
    private var lastOutlineWidth: CGFloat?
    private(set) var modelID: UUID?

    private enum SplitRatio {
        static let fileEdge: CGFloat = 28
        static let pinnedFolderFiles: CGFloat = 0.24
        static let folderOutline: CGFloat = 0.20
        static let singleFileOutline: CGFloat = 0.20
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

    var fileDirectoryModeForTesting: FileDirectoryMode {
        fileDirectoryMode
    }

    var isFileDrawerVisibleForTesting: Bool {
        fileDirectoryMode == .hoverOpen
    }

    var isOutlineVisibleForTesting: Bool {
        isOutlineVisible
    }

    var isSingleFileFileDirectoryHiddenForTesting: Bool {
        guard currentWindowModel?.layoutMode == .outlineAndDocument else { return false }
        return sidebar.filesContainer.isHidden
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
        splitView.delegate = self
        root.addSubview(tabBar.view)
        root.addSubview(splitView)
        root.addSubview(sidebar.fileDrawerView)
        root.addSubview(outlineToggleButton)
        NSLayoutConstraint.activate([
            tabBar.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            tabBar.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            tabBar.view.topAnchor.constraint(equalTo: root.topAnchor),
            tabBar.view.heightAnchor.constraint(equalToConstant: 34),
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: tabBar.view.bottomAnchor),
            splitView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.fileDrawerView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.fileDrawerView.topAnchor.constraint(equalTo: tabBar.view.bottomAnchor),
            sidebar.fileDrawerView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.fileDrawerView.widthAnchor.constraint(equalToConstant: 286)
        ])
        sidebar.filesContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebar.outlineContainer.translatesAutoresizingMaskIntoConstraints = false
        renderer.view.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(sidebar.filesContainer)
        splitView.addArrangedSubview(sidebar.outlineContainer)
        splitView.addArrangedSubview(renderer.view)
        if let rendererURL = Bundle.main.resourceURL?.appendingPathComponent("renderer/index.html") {
            renderer.loadRenderer(from: rendererURL)
        }
        sidebar.onSelectFile = { [weak self] relativePath in
            guard let self, let root = self.currentWorkspaceRoot else { return }
            self.onOpenWorkspaceFile?(root.appendingPathComponent(relativePath))
            self.closeFileDrawerIfTemporary()
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
        sidebar.configureFileDirectoryActions(
            open: { [weak self] in self?.openFileDrawer() },
            pin: { [weak self] in self?.pinFileDirectory() },
            unpin: { [weak self] in self?.collapseFileDirectoryToEdge() },
            drawerMouseExit: { [weak self] in self?.closeFileDrawerIfTemporary() }
        )
        updateNavigationControls()
    }

    private func makeNavigationIconButton(symbolName: String, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        button.translatesAutoresizingMaskIntoConstraints = true
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = action
        button.isHidden = true
        return button
    }

    @objc private func toggleOutlineFromNavigationButton() {
        toggleOutline()
    }

    func openFileDrawerForTesting() {
        openFileDrawer()
    }

    func closeFileDrawerForTesting() {
        closeFileDrawerIfTemporary()
    }

    func pinFileDirectoryForTesting() {
        pinFileDirectory()
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
            resetNavigationState(for: windowModel.layoutMode)
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
        updateNavigationControls(for: windowModel.layoutMode)
    }

    private func resetNavigationState(for layoutMode: LayoutMode) {
        fileDirectoryMode = .edgeCollapsed
        isOutlineVisible = true
        lastPinnedFilesWidth = nil
        lastOutlineWidth = nil
        sidebar.setFilesCollapsed(false)
        sidebar.setOutlineCollapsed(false)
        sidebar.outlineContainer.isHidden = false
        switch layoutMode {
        case .filesOutlineAndDocument:
            sidebar.filesContainer.isHidden = false
        case .outlineAndDocument:
            sidebar.filesContainer.isHidden = true
        }
        updateNavigationControls(for: layoutMode)
    }

    private func updateNavigationControls(for layoutMode: LayoutMode? = nil) {
        let mode = layoutMode ?? currentWindowModel?.layoutMode
        let outlineLabel = isOutlineVisible ? "隐藏目录" : "显示目录"
        outlineToggleButton.isHidden = mode == nil
        outlineToggleButton.setAccessibilityLabel(outlineLabel)
        outlineToggleButton.toolTip = outlineLabel
        layoutNavigationControls()
    }

    private func layoutNavigationControls() {
        guard !outlineToggleButton.isHidden, let root = window?.contentView else { return }
        let origin = splitView.convert(
            NSPoint(x: renderer.view.frame.minX + 14, y: 12 + outlineToggleButton.bounds.height),
            to: root
        )
        outlineToggleButton.frame = NSRect(
            x: round(origin.x),
            y: round(origin.y),
            width: outlineToggleButton.bounds.width,
            height: outlineToggleButton.bounds.height
        )
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
            sidebar.outlineContainer.isHidden = !isOutlineVisible
            splitView.setPosition(SplitRatio.fileEdge, ofDividerAt: 0)
            splitView.setPosition(
                SplitRatio.fileEdge + totalWidth * SplitRatio.folderOutline + splitView.dividerThickness,
                ofDividerAt: 1
            )
            splitView.setPosition(SplitRatio.fileEdge, ofDividerAt: 0)
        case .outlineAndDocument:
            sidebar.filesContainer.isHidden = true
            sidebar.outlineContainer.isHidden = !isOutlineVisible
            splitView.setPosition(0, ofDividerAt: 0)
            splitView.setPosition(totalWidth * SplitRatio.singleFileOutline + splitView.dividerThickness, ofDividerAt: 1)
        }

        splitView.layoutSubtreeIfNeeded()
        layoutNavigationControls()
    }

    private func render(tab: DocumentTab, workspaceRoot: URL?) {
        resourceHandler.root = workspaceRoot ?? tab.url.deletingLastPathComponent()
        resourceHandler.currentDocument = tab.url
        do {
            let content = try String(contentsOf: tab.url, encoding: .utf8)
            sidebar.renderOutline(MarkdownOutline.parse(content))
            renderer.render(
                path: tab.url.path,
                name: tab.title,
                content: content,
                scrollPosition: tab.scrollPosition,
                readerLayout: currentReaderLayout
            )
        } catch {
            let message = "文件不存在：\(tab.url.path)"
            sidebar.renderOutline(MarkdownOutline.parse(message))
            renderer.render(
                path: tab.url.path,
                name: tab.title,
                content: message,
                scrollPosition: tab.scrollPosition,
                readerLayout: currentReaderLayout
            )
        }
    }

    private var currentReaderLayout: ReaderLayout {
        isOutlineVisible ? .withOutline : .centered
    }

    func toggleFiles() {
        guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
        if fileDirectoryMode == .pinned {
            collapseFileDirectoryToEdge()
        } else {
            pinFileDirectory()
        }
    }

    private func openFileDrawer() {
        guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
        guard fileDirectoryMode != .pinned else { return }
        fileDirectoryMode = .hoverOpen
        sidebar.showFileDrawer(true)
        updateNavigationControls()
    }

    private func closeFileDrawerIfTemporary() {
        guard fileDirectoryMode == .hoverOpen else { return }
        fileDirectoryMode = .edgeCollapsed
        sidebar.showFileDrawer(false)
        updateNavigationControls()
    }

    private func collapseFileDirectoryToEdge() {
        guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
        if fileDirectoryMode == .pinned {
            let currentWidth = splitView.subviews[0].frame.width
            if currentWidth > SplitRatio.fileEdge {
                lastPinnedFilesWidth = currentWidth
            }
        }
        fileDirectoryMode = .edgeCollapsed
        sidebar.showFileEdgeTrigger()
        sidebar.showFileDrawer(false)
        splitView.setPosition(SplitRatio.fileEdge, ofDividerAt: 0)
        if isOutlineVisible {
            restoreOutlinePositionAfterFileWidthChange(fileWidth: SplitRatio.fileEdge)
        }
        splitView.setPosition(SplitRatio.fileEdge, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        updateNavigationControls()
    }

    private func pinFileDirectory() {
        guard currentWindowModel?.layoutMode == .filesOutlineAndDocument else { return }
        splitView.layoutSubtreeIfNeeded()

        let targetWidth = lastPinnedFilesWidth ?? max(
            SplitRatio.fileEdge,
            splitView.bounds.width * SplitRatio.pinnedFolderFiles
        )
        fileDirectoryMode = .pinned
        sidebar.showPinnedFilesPane()
        sidebar.showFileDrawer(false)
        splitView.setPosition(targetWidth, ofDividerAt: 0)
        restoreOutlinePositionAfterFileWidthChange(fileWidth: targetWidth)
        splitView.setPosition(targetWidth, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        updateNavigationControls()
    }

    private func restoreOutlinePositionAfterFileWidthChange(fileWidth: CGFloat) {
        guard isOutlineVisible else { return }
        let outlineWidth = lastOutlineWidth ?? splitView.bounds.width * SplitRatio.folderOutline
        splitView.setPosition(fileWidth + outlineWidth + splitView.dividerThickness, ofDividerAt: 1)
    }

    func toggleOutline() {
        if isOutlineVisible {
            hideOutlineNavigation()
        } else {
            showOutlineNavigation()
        }
    }

    private func hideOutlineNavigation() {
        guard isOutlineVisible else { return }
        splitView.layoutSubtreeIfNeeded()
        let currentWidth = splitView.subviews[1].frame.width
        if currentWidth > 0 {
            lastOutlineWidth = currentWidth
        }
        isOutlineVisible = false
        sidebar.setOutlineCollapsed(true)
        sidebar.outlineContainer.isHidden = true

        if currentWindowModel?.layoutMode == .outlineAndDocument {
            splitView.setPosition(0, ofDividerAt: 0)
            splitView.setPosition(0, ofDividerAt: 1)
        } else {
            let fileWidth = splitView.subviews[0].frame.width
            splitView.setPosition(fileWidth, ofDividerAt: 1)
        }

        splitView.layoutSubtreeIfNeeded()
        renderer.setReaderLayout(currentReaderLayout)
        updateNavigationControls()
    }

    private func showOutlineNavigation() {
        guard !isOutlineVisible else { return }
        let targetWidth = lastOutlineWidth ?? splitView.bounds.width * (
            currentWindowModel?.layoutMode == .outlineAndDocument
                ? SplitRatio.singleFileOutline
                : SplitRatio.folderOutline
        )
        isOutlineVisible = true
        sidebar.outlineContainer.isHidden = false
        sidebar.setOutlineCollapsed(false)

        if currentWindowModel?.layoutMode == .outlineAndDocument {
            sidebar.filesContainer.isHidden = true
            splitView.setPosition(0, ofDividerAt: 0)
            splitView.setPosition(targetWidth + splitView.dividerThickness, ofDividerAt: 1)
        } else {
            let fileWidth = splitView.subviews[0].frame.width
            splitView.setPosition(fileWidth + targetWidth + splitView.dividerThickness, ofDividerAt: 1)
            splitView.setPosition(fileWidth, ofDividerAt: 0)
        }

        splitView.layoutSubtreeIfNeeded()
        renderer.setReaderLayout(currentReaderLayout)
        updateNavigationControls()
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

final class ReaderSplitView: NSSplitView {
    private enum Divider {
        static let dragWidth: CGFloat = 10
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        dividerStyle = .thin
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        dividerStyle = .thin
    }

    override var dividerThickness: CGFloat {
        Divider.dragWidth
    }

    override func drawDivider(in rect: NSRect) {
        NSColor.white.setFill()
        rect.fill()
    }
}

extension MainWindowController: NSSplitViewDelegate {
    func splitViewDidResizeSubviews(_ notification: Notification) {
        layoutNavigationControls()
    }
}
