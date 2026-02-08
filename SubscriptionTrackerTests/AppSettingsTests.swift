import Foundation
import Testing
@testable import SubsKun

struct AppSettingsTests {
    @Test
    func themeColorFallsBackToBlueForInvalidStoredValue() {
        let defaults = makeDefaults()
        defaults.set("invalid-color", forKey: "settings.themeColor")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.themeColor == .blue)
        #expect(settings.themeColorRaw == ThemeColorOption.blue.rawValue)
    }

    @Test
    func themeColorSupportsNewPaletteOptions() {
        let defaults = makeDefaults()

        let settings = AppSettings(defaults: defaults)
        settings.themeColor = .purple

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.themeColor == .purple)
        #expect(reloaded.themeColorRaw == ThemeColorOption.purple.rawValue)
    }

    @Test
    func themeColorKeepsBackwardCompatibleValues() {
        let defaults = makeDefaults()
        defaults.set("teal", forKey: "settings.themeColor")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.themeColor == .teal)
        #expect(settings.themeColorRaw == ThemeColorOption.teal.rawValue)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
