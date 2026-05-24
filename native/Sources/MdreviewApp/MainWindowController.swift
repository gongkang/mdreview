import AppKit
import MdreviewCore

final class MainWindowController: NSWindowController {
    private let splitView = NSSplitView()
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
    private(set) var modelID: UUID?

    private enum SplitRatio {
        static let folderFiles: CGFloat = 0.17
        static let folderOutline: CGFloat = 0.14
        static let singleFileOutline: CGFloat = 0.16
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
        sidebar.filesView.translatesAutoresizingMaskIntoConstraints = false
        sidebar.outlineView.translatesAutoresizingMaskIntoConstraints = false
        renderer.view.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(sidebar.filesView)
        splitView.addArrangedSubview(sidebar.outlineView)
        splitView.addArrangedSubview(renderer.view)
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
    }

    func apply(windowModel: WindowModel) {
        modelID = windowModel.id
        currentWindowModel = windowModel
        currentWorkspaceRoot = windowModel.workspaceRoot
        tabBar.render(tabs: windowModel.tabs, activeTabID: windowModel.activeTabID)
        let shouldApplyDefaultRatio = lastAppliedLayoutMode != windowModel.layoutMode
        lastAppliedLayoutMode = windowModel.layoutMode
        sidebar.apply(layoutMode: windowModel.layoutMode)
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
            sidebar.filesView.isHidden = false
            splitView.setPosition(totalWidth * SplitRatio.folderFiles, ofDividerAt: 0)
            splitView.setPosition(totalWidth * (SplitRatio.folderFiles + SplitRatio.folderOutline), ofDividerAt: 1)
            splitView.setPosition(totalWidth * SplitRatio.folderFiles, ofDividerAt: 0)
        case .outlineAndDocument:
            sidebar.filesView.isHidden = true
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
        sidebar.toggleFiles()
    }

    func toggleOutline() {
        sidebar.toggleOutline()
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
