import AppKit
import MdreviewCore

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private var settings = SettingsStore.load()
    private let openFolders = NSButton(checkboxWithTitle: "打开文件夹时默认新建窗口", target: nil, action: nil)
    private let autoRefresh = NSButton(checkboxWithTitle: "自动刷新单文件", target: nil, action: nil)
    private let restoreWindow = NSButton(checkboxWithTitle: "启动时恢复上次窗口", target: nil, action: nil)
    private let showFiles = NSButton(checkboxWithTitle: "显示文件栏", target: nil, action: nil)
    private let showOutline = NSButton(checkboxWithTitle: "显示大纲栏", target: nil, action: nil)
    private let filesWidth = NSTextField()
    private let outlineWidth = NSTextField()

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "设置"
        buildContent()
        apply(settings)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func buildContent() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView?.addSubview(stack)
        [openFolders, autoRefresh, restoreWindow, widthRow(label: "文件栏默认宽度", field: filesWidth), widthRow(label: "大纲栏默认宽度", field: outlineWidth), showFiles, showOutline].forEach {
            stack.addArrangedSubview($0)
        }
        [openFolders, autoRefresh, restoreWindow, showFiles, showOutline].forEach {
            $0.target = self
            $0.action = #selector(save)
        }
        [filesWidth, outlineWidth].forEach {
            $0.target = self
            $0.action = #selector(save)
            $0.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }
        if let content = window?.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor)
            ])
        }
    }

    private func widthRow(label: String, field: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.addArrangedSubview(NSTextField(labelWithString: label))
        row.addArrangedSubview(field)
        return row
    }

    private func apply(_ settings: AppSettings) {
        openFolders.state = settings.openFoldersInNewWindow ? .on : .off
        autoRefresh.state = settings.autoRefreshSingleFile ? .on : .off
        restoreWindow.state = settings.restoreLastWindow ? .on : .off
        showFiles.state = settings.showFiles ? .on : .off
        showOutline.state = settings.showOutline ? .on : .off
        filesWidth.stringValue = String(Int(settings.filesWidth))
        outlineWidth.stringValue = String(Int(settings.outlineWidth))
    }

    @objc private func save() {
        settings = AppSettings(
            openFoldersInNewWindow: openFolders.state == .on,
            autoRefreshSingleFile: autoRefresh.state == .on,
            restoreLastWindow: restoreWindow.state == .on,
            filesWidth: Double(filesWidth.stringValue) ?? AppSettings.defaults.filesWidth,
            outlineWidth: Double(outlineWidth.stringValue) ?? AppSettings.defaults.outlineWidth,
            showFiles: showFiles.state == .on,
            showOutline: showOutline.state == .on
        )
        SettingsStore.save(settings)
    }
}
