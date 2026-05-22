import Foundation

public enum AppCommand: Sendable {
    case openFile(URL, newWindow: Bool)
    case openDirectory(URL, defaultDocument: URL, fileTree: [MarkdownNode], newWindow: Bool)
}

public enum ReducerResult: Equatable, Sendable {
    case opened
    case focused
}

public enum AppReducer {
    public static func apply(_ command: AppCommand, to model: inout AppModel) -> ReducerResult {
        switch command {
        case let .openFile(url, newWindow):
            return openFile(url, newWindow: newWindow, model: &model)
        case let .openDirectory(root, defaultDocument, fileTree, newWindow):
            return openDirectory(root, defaultDocument: defaultDocument, fileTree: fileTree, newWindow: newWindow, model: &model)
        }
    }

    private static func openFile(_ url: URL, newWindow: Bool, model: inout AppModel) -> ReducerResult {
        for windowIndex in model.windows.indices {
            if let tab = model.windows[windowIndex].tabs.first(where: { $0.url.path == url.path }) {
                model.windows[windowIndex].activeTabID = tab.id
                model.activeWindowID = model.windows[windowIndex].id
                return .focused
            }
        }

        let tab = DocumentTab(url: url)
        if newWindow || model.windows.isEmpty {
            let window = WindowModel(tabs: [tab], activeTabID: tab.id, layoutMode: .outlineAndDocument)
            model.windows.append(window)
            model.activeWindowID = window.id
            return .opened
        }

        let index = activeWindowIndex(in: model) ?? 0
        model.windows[index].tabs.append(tab)
        model.windows[index].activeTabID = tab.id
        if model.windows[index].workspaceRoot == nil {
            model.windows[index].layoutMode = .outlineAndDocument
        }
        model.activeWindowID = model.windows[index].id
        return .opened
    }

    private static func openDirectory(_ root: URL, defaultDocument: URL, fileTree: [MarkdownNode], newWindow: Bool, model: inout AppModel) -> ReducerResult {
        let tab = DocumentTab(url: defaultDocument)
        let replacement = WindowModel(workspaceRoot: root, fileTree: fileTree, tabs: [tab], activeTabID: tab.id, layoutMode: .filesOutlineAndDocument)

        if newWindow || model.windows.isEmpty {
            model.windows.append(replacement)
            model.activeWindowID = replacement.id
            return .opened
        }

        let index = activeWindowIndex(in: model) ?? 0
        model.windows[index] = WindowModel(id: model.windows[index].id, workspaceRoot: root, fileTree: fileTree, tabs: [tab], activeTabID: tab.id, layoutMode: .filesOutlineAndDocument)
        model.activeWindowID = model.windows[index].id
        return .opened
    }

    private static func activeWindowIndex(in model: AppModel) -> Array<WindowModel>.Index? {
        guard let id = model.activeWindowID else { return nil }
        return model.windows.firstIndex(where: { $0.id == id })
    }
}
