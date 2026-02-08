import Foundation
import Testing

struct LocalizationSmokeTests {
    @Test
    func localizableFilesContainRequiredKeysForJaAndEn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let jaFile = root.appendingPathComponent("SubscriptionTracker/Resources/ja.lproj/Localizable.strings")
        let enFile = root.appendingPathComponent("SubscriptionTracker/Resources/en.lproj/Localizable.strings")

        let jaText = try String(contentsOf: jaFile, encoding: .utf8)
        let enText = try String(contentsOf: enFile, encoding: .utf8)

        let requiredKeys = [
            "tab.ratio",
            "tab.history",
            "tab.list",
            "tab.settings",
            "settings.navigation_title",
            "settings.language",
            "settings.theme.color",
            "summary.navigation_title",
            "history.navigation_title",
            "subscription.list.navigation_title",
            "subscription.edit.navigation_title.add",
            "subscription.detail.section.basic",
            "common.year_number_format",
            "common.month_number_short",
            "export.navigation_title"
        ]

        for key in requiredKeys {
            #expect(jaText.contains("\"\(key)\" = "))
            #expect(enText.contains("\"\(key)\" = "))
        }
    }
}
