import AppKit
import MdreviewCore

final class MainWindowController: NSWindowController {
    private let splitView = NSSplitView()
    private let tabBar = DocumentTabBar()
    private let sidebar = SidebarController()
    private let content = NSTextView()
    private var didBuildLayout = false

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
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        stack.addArrangedSubview(tabBar.view)
        stack.addArrangedSubview(splitView)
        tabBar.view.heightAnchor.constraint(equalToConstant: 34).isActive = true
        splitView.addArrangedSubview(sidebar.filesView)
        splitView.addArrangedSubview(sidebar.outlineView)
        let contentScrollView = NSScrollView()
        contentScrollView.documentView = content
        contentScrollView.hasVerticalScroller = true
        splitView.addArrangedSubview(contentScrollView)
        sidebar.filesView.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        sidebar.outlineView.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        content.string = "请选择 Markdown 文件"
        content.isEditable = false
    }

    func apply(windowModel: WindowModel) {
        tabBar.render(tabs: windowModel.tabs, activeTabID: windowModel.activeTabID)
        sidebar.apply(layoutMode: windowModel.layoutMode)
        let active = windowModel.tabs.first(where: { $0.id == windowModel.activeTabID })
        window?.title = active?.title ?? "mdreview"
    }
}
