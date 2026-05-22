import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var openFoldersInNewWindow: Bool
    public var autoRefreshSingleFile: Bool
    public var restoreLastWindow: Bool
    public var filesWidth: Double
    public var outlineWidth: Double
    public var showFiles: Bool
    public var showOutline: Bool

    public init(openFoldersInNewWindow: Bool, autoRefreshSingleFile: Bool, restoreLastWindow: Bool, filesWidth: Double, outlineWidth: Double, showFiles: Bool, showOutline: Bool) {
        self.openFoldersInNewWindow = openFoldersInNewWindow
        self.autoRefreshSingleFile = autoRefreshSingleFile
        self.restoreLastWindow = restoreLastWindow
        self.filesWidth = filesWidth
        self.outlineWidth = outlineWidth
        self.showFiles = showFiles
        self.showOutline = showOutline
    }

    public static let defaults = AppSettings(
        openFoldersInNewWindow: false,
        autoRefreshSingleFile: true,
        restoreLastWindow: false,
        filesWidth: 220,
        outlineWidth: 180,
        showFiles: true,
        showOutline: true
    )
}
