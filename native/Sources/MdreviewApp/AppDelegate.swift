import AppKit
import MdreviewCore
import MdreviewIPC

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [MainWindowController] = []
    private var model = AppModel()
    private var socketServer: SocketServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = buildMenu()
        startIPCServer()
        openEmptyWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
    }

    private func openEmptyWindow() {
        createWindow(activate: true)
    }

    private func createWindow(activate: Bool) {
        let controller = MainWindowController()
        controller.onOpenWorkspaceFile = { [weak self] url in
            _ = self?.handleOpenRequest(OpenRequest(kind: .openFile, path: url.path, newWindow: false))
        }
        controller.onSelectTab = { [weak self, weak controller] tabID in
            guard let self, let controller,
                  let index = self.windows.firstIndex(where: { $0 === controller }),
                  self.model.windows.indices.contains(index) else { return }
            self.model.windows[index].activeTabID = tabID
            self.model.activeWindowID = self.model.windows[index].id
            self.synchronizeWindows()
        }
        windows.append(controller)
        controller.showWindow(nil)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func startIPCServer() {
        do {
            let server = try SocketServer(socketPath: SocketLocation.defaultPath()) { [weak self] request in
                guard let self else {
                    return OpenResponse(accepted: false, action: .rejected, message: "App 尚未就绪")
                }
                return DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        self.handleOpenRequest(request)
                    }
                }
            }
            try server.start()
            socketServer = server
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法启动命令行入口"
            alert.informativeText = String(describing: error)
            alert.runModal()
        }
    }

    @discardableResult
    private func handleOpenRequest(_ request: OpenRequest) -> OpenResponse {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: request.path, isDirectory: &isDirectory) else {
            return OpenResponse(accepted: false, action: .rejected, message: "路径不存在：\(request.path)")
        }

        let url = PathValidation.canonicalURL(URL(fileURLWithPath: request.path))
        let result: ReducerResult
        switch request.kind {
        case .openFile:
            guard !isDirectory.boolValue else {
                return OpenResponse(accepted: false, action: .rejected, message: "路径不是文件：\(request.path)")
            }
            result = AppReducer.apply(.openFile(url, newWindow: request.newWindow), to: &model)
        case .openDirectory:
            guard isDirectory.boolValue else {
                return OpenResponse(accepted: false, action: .rejected, message: "路径不是目录：\(request.path)")
            }
            do {
                let tree = try MarkdownTree.scan(root: url)
                guard let defaultRelativePath = MarkdownTree.defaultDocument(in: tree) else {
                    return OpenResponse(accepted: false, action: .rejected, message: "目录中没有 Markdown 文件：\(request.path)")
                }
                let defaultDocument = url.appendingPathComponent(defaultRelativePath)
                result = AppReducer.apply(.openDirectory(url, defaultDocument: defaultDocument, fileTree: tree, newWindow: request.newWindow), to: &model)
            } catch {
                return OpenResponse(accepted: false, action: .rejected, message: "无法扫描目录：\(request.path)")
            }
        }

        synchronizeWindows()
        let action: OpenResponseAction = result == .focused ? .focused : .opened
        return OpenResponse(accepted: true, action: action, message: result == .focused ? "已聚焦" : "已打开")
    }

    private func synchronizeWindows() {
        let modelWindowIDs = Set(model.windows.map(\.id))
        for index in windows.indices.reversed() {
            guard let id = windows[index].modelID,
                  !modelWindowIDs.contains(id) else { continue }
            windows[index].close()
            windows.remove(at: index)
        }
        while windows.count < model.windows.count {
            createWindow(activate: false)
        }
        for (index, windowModel) in model.windows.enumerated() {
            windows[index].apply(windowModel: windowModel)
        }
        if let activeID = model.activeWindowID,
           let activeIndex = model.windows.firstIndex(where: { $0.id == activeID }) {
            windows[activeIndex].showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func buildMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: MenuText.appName)
        appMenu.addItem(menuItem(title: MenuText.settings, action: #selector(openSettings), keyEquivalent: ","))
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: MenuText.file)
        fileMenu.addItem(menuItem(title: MenuText.openFile, action: #selector(openFile), keyEquivalent: "o"))
        fileMenu.addItem(menuItem(title: MenuText.openFolder, action: #selector(openFolder), keyEquivalent: "O"))
        fileMenu.addItem(menuItem(title: MenuText.openFolderInNewWindow, action: #selector(openFolderInNewWindow), keyEquivalent: "n"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(menuItem(title: MenuText.closeTab, action: #selector(closeTab), keyEquivalent: "w"))
        fileMenu.addItem(NSMenuItem(title: MenuText.closeWindow, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "W"))
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: MenuText.view)
        viewMenu.addItem(menuItem(title: MenuText.toggleFiles, action: #selector(toggleFiles), keyEquivalent: "1"))
        viewMenu.addItem(menuItem(title: MenuText.toggleOutline, action: #selector(toggleOutline), keyEquivalent: "2"))
        viewMenu.addItem(menuItem(title: MenuText.reloadCurrentDocument, action: #selector(reloadDocument), keyEquivalent: "r"))
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        main.addItem(NSMenuItem(title: MenuText.window, action: nil, keyEquivalent: ""))
        return main
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showCentered(relativeTo: activeController()?.window)
    }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            _ = handleOpenRequest(OpenRequest(kind: .openFile, path: url.path, newWindow: false))
        }
    }

    @objc private func openFolder() {
        openFolderPanel(newWindow: false)
    }

    @objc private func openFolderInNewWindow() {
        openFolderPanel(newWindow: true)
    }

    private func openFolderPanel(newWindow: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            _ = handleOpenRequest(OpenRequest(kind: .openDirectory, path: url.path, newWindow: newWindow))
        }
    }

    @objc private func closeTab() {
        AppReducer.closeActiveTab(in: &model)
        synchronizeWindows()
        if model.windows.isEmpty {
            NSApp.terminate(nil)
        }
    }

    @objc private func toggleFiles() {
        activeController()?.toggleFiles()
    }

    @objc private func toggleOutline() {
        activeController()?.toggleOutline()
    }

    @objc private func reloadDocument() {
        activeController()?.reloadDocument()
    }

    private func activeWindowIndex() -> Array<WindowModel>.Index? {
        guard let id = model.activeWindowID else { return nil }
        return model.windows.firstIndex(where: { $0.id == id })
    }

    private func activeController() -> MainWindowController? {
        if let key = windows.first(where: { $0.window?.isKeyWindow == true }) {
            return key
        }
        guard let activeID = model.activeWindowID,
              let index = model.windows.firstIndex(where: { $0.id == activeID }) else { return windows.last }
        return windows.indices.contains(index) ? windows[index] : windows.last
    }
}
