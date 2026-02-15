import Foundation
import SwiftData
import Testing
@testable import SubsKun

struct AccountDeletionTests {
    // MARK: - AppSettings.resetToDefaults

    @Test
    func resetToDefaultsRestoresAllValues() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.defaultCurrency = "USD"
        settings.pastMonths = 12
        settings.futureMonths = 24
        settings.includePausedInSummary = true
        settings.themeMode = .dark
        settings.themeColor = .red
        settings.notifyBeforeBilling = false

        settings.resetToDefaults()

        #expect(settings.defaultCurrency == "JPY")
        #expect(settings.pastMonths == 6)
        #expect(settings.futureMonths == 12)
        #expect(settings.includePausedInSummary == false)
        #expect(settings.themeMode == .system)
        #expect(settings.themeColor == .blue)
        #expect(settings.notifyBeforeBilling == true)
    }

    @Test
    func resetToDefaultsProducesCleanReloadedState() {
        let suiteName = "AccountDeletionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settings = AppSettings(defaults: defaults)
        settings.defaultCurrency = "EUR"
        settings.themeColor = .pink

        settings.resetToDefaults()

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.defaultCurrency == "JPY")
        #expect(reloaded.themeColor == .blue)
    }

    // MARK: - AuthenticationStore.deleteAccount clears UserDefaults keys

    @Test
    func deleteAccountClearsAuthKeys() async {
        await MainActor.run {
            let defaults = makeDefaults()

            let userData = try! JSONEncoder().encode(AuthSessionUser(
                id: "test-user",
                provider: .google,
                displayName: "Test",
                email: "test@example.com"
            ))
            defaults.set(userData, forKey: "auth.currentUser")
            defaults.set(Data(), forKey: "auth.appleIdentityCache")
            defaults.set(Data(), forKey: "auth.emailRegistry")
            defaults.set("cached", forKey: "exchange_rate.snapshot.v1")
            defaults.set("cached", forKey: "service_catalog.payload.v1")

            let store = AuthenticationStore(defaults: defaults)

            #expect(store.currentUser != nil)

            let settings = AppSettings(defaults: defaults)
            settings.defaultCurrency = "USD"

            let context = makeInMemoryModelContext()
            store.deleteAccount(modelContext: context, settings: settings)

            #expect(store.currentUser == nil)
            #expect(defaults.object(forKey: "auth.currentUser") == nil)
            #expect(defaults.object(forKey: "auth.appleIdentityCache") == nil)
            #expect(defaults.object(forKey: "auth.emailRegistry") == nil)
            #expect(defaults.object(forKey: "exchange_rate.snapshot.v1") == nil)
            #expect(defaults.object(forKey: "service_catalog.payload.v1") == nil)
            #expect(settings.defaultCurrency == "JPY")
        }
    }

    @Test
    func deleteAccountDoesNotCrashWhenNotSignedIn() async {
        await MainActor.run {
            let defaults = makeDefaults()
            let store = AuthenticationStore(defaults: defaults)
            let settings = AppSettings(defaults: defaults)

            #expect(store.currentUser == nil)

            let context = makeInMemoryModelContext()
            store.deleteAccount(modelContext: context, settings: settings)

            #expect(store.currentUser == nil)
        }
    }

    // MARK: - Helpers

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AccountDeletionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeInMemoryModelContext() -> ModelContext {
        let schema = Schema([Subscription.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
}
