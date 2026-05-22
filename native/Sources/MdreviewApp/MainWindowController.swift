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
    private var settings = SettingsStore.load()
    private var filesWidthConstraint: NSLayoutConstraint?
    private var outlineWidthConstraint: NSLayoutConstraint?
    private(set) var modelID: UUID?

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
        filesWidthConstraint = sidebar.filesView.widthAnchor.constraint(equalToConstant: CGFloat(settings.filesWidth))
        outlineWidthConstraint = sidebar.outlineView.widthAnchor.constraint(equalToConstant: CGFloat(settings.outlineWidth))
        filesWidthConstraint?.priority = .defaultHigh
        outlineWidthConstraint?.priority = .defaultHigh
        let rendererMinimumWidth = renderer.view.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        rendererMinimumWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([filesWidthConstraint, outlineWidthConstraint, rendererMinimumWidth].compactMap { $0 })
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
        sidebar.apply(layoutMode: windowModel.layoutMode)
        applySidebarWidths(layoutMode: windowModel.layoutMode)
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
    }

    private func applySidebarWidths(layoutMode: LayoutMode) {
        filesWidthConstraint?.constant = layoutMode == .outlineAndDocument ? 0 : CGFloat(settings.filesWidth)
        outlineWidthConstraint?.constant = CGFloat(settings.outlineWidth)
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
