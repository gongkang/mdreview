import XCTest
@testable import MdreviewCore

final class SettingsTests: XCTestCase {
    func testDefaultSettingsMatchSpec() {
        let defaults = AppSettings.defaults
        XCTAssertFalse(defaults.openFoldersInNewWindow)
        XCTAssertTrue(defaults.autoRefreshSingleFile)
        XCTAssertFalse(defaults.restoreLastWindow)
        XCTAssertEqual(defaults.filesWidth, 220)
        XCTAssertEqual(defaults.outlineWidth, 180)
    }

    func testSettingsPersistToUserDefaults() {
        let suite = "mdreview.settings.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(
            openFoldersInNewWindow: true,
            autoRefreshSingleFile: false,
            restoreLastWindow: true,
            filesWidth: 260,
            outlineWidth: 210,
            showFiles: false,
            showOutline: true
        )
        SettingsStore.save(settings, defaults: defaults)

        XCTAssertEqual(SettingsStore.load(defaults: defaults), settings)
    }
}
