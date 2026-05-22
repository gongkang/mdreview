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

public enum SettingsStore {
    private enum Keys {
        static let openFoldersInNewWindow = "openFoldersInNewWindow"
        static let autoRefreshSingleFile = "autoRefreshSingleFile"
        static let restoreLastWindow = "restoreLastWindow"
        static let filesWidth = "filesWidth"
        static let outlineWidth = "outlineWidth"
        static let showFiles = "showFiles"
        static let showOutline = "showOutline"
    }

    public static func load(defaults: UserDefaults = .standard) -> AppSettings {
        let fallback = AppSettings.defaults
        return AppSettings(
            openFoldersInNewWindow: defaults.object(forKey: Keys.openFoldersInNewWindow) as? Bool ?? fallback.openFoldersInNewWindow,
            autoRefreshSingleFile: defaults.object(forKey: Keys.autoRefreshSingleFile) as? Bool ?? fallback.autoRefreshSingleFile,
            restoreLastWindow: defaults.object(forKey: Keys.restoreLastWindow) as? Bool ?? fallback.restoreLastWindow,
            filesWidth: defaults.object(forKey: Keys.filesWidth) as? Double ?? fallback.filesWidth,
            outlineWidth: defaults.object(forKey: Keys.outlineWidth) as? Double ?? fallback.outlineWidth,
            showFiles: defaults.object(forKey: Keys.showFiles) as? Bool ?? fallback.showFiles,
            showOutline: defaults.object(forKey: Keys.showOutline) as? Bool ?? fallback.showOutline
        )
    }

    public static func save(_ settings: AppSettings, defaults: UserDefaults = .standard) {
        defaults.set(settings.openFoldersInNewWindow, forKey: Keys.openFoldersInNewWindow)
        defaults.set(settings.autoRefreshSingleFile, forKey: Keys.autoRefreshSingleFile)
        defaults.set(settings.restoreLastWindow, forKey: Keys.restoreLastWindow)
        defaults.set(settings.filesWidth, forKey: Keys.filesWidth)
        defaults.set(settings.outlineWidth, forKey: Keys.outlineWidth)
        defaults.set(settings.showFiles, forKey: Keys.showFiles)
        defaults.set(settings.showOutline, forKey: Keys.showOutline)
    }
}
