import Foundation

public enum LayoutMode: String, Codable, Equatable {
    case filesOutlineAndDocument
    case outlineAndDocument
}

public struct DocumentTab: Codable, Equatable, Identifiable {
    public let id: UUID
    public let url: URL
    public var title: String
    public var scrollPosition: Double

    public init(id: UUID = UUID(), url: URL, title: String? = nil, scrollPosition: Double = 0) {
        self.id = id
        self.url = url
        self.title = title ?? url.lastPathComponent
        self.scrollPosition = scrollPosition
    }
}

public struct WindowModel: Codable, Equatable, Identifiable {
    public let id: UUID
    public var workspaceRoot: URL?
    public var fileTree: [MarkdownNode]
    public var tabs: [DocumentTab]
    public var activeTabID: UUID?
    public var layoutMode: LayoutMode

    public init(id: UUID = UUID(), workspaceRoot: URL? = nil, fileTree: [MarkdownNode] = [], tabs: [DocumentTab] = [], activeTabID: UUID? = nil, layoutMode: LayoutMode = .outlineAndDocument) {
        self.id = id
        self.workspaceRoot = workspaceRoot
        self.fileTree = fileTree
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.layoutMode = layoutMode
    }
}

public struct AppModel: Codable, Equatable {
    public var windows: [WindowModel]
    public var activeWindowID: UUID?

    public init(windows: [WindowModel] = [], activeWindowID: UUID? = nil) {
        self.windows = windows
        self.activeWindowID = activeWindowID
    }
}
