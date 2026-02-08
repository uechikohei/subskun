import Foundation
import Testing
@testable import SubsKun

@MainActor
struct ServiceCatalogStoreTests {
    @Test
    func suggestionsMatchAliasAndPrefix() {
        let defaults = makeDefaults()
        let store = ServiceCatalogStore(
            defaults: defaults,
            bundledPayloadData: Data(samplePayload.utf8),
            remoteCatalogURL: nil
        )

        #expect(store.entries.count == 3)
        #expect(store.suggestions(for: "chat").first?.name == "ChatGPT")
        #expect(store.suggestions(for: "twitter").first?.name == "X Premium")
    }

    @Test
    func exactMatchFindsByAlias() {
        let defaults = makeDefaults()
        let store = ServiceCatalogStore(
            defaults: defaults,
            bundledPayloadData: Data(samplePayload.utf8),
            remoteCatalogURL: nil
        )

        let entry = store.exactMatch(for: "OpenAI ChatGPT")
        #expect(entry?.id == "chatgpt")
        #expect(entry?.primaryCategory == "AI")
    }

    @Test
    func suggestionsMatchJapaneseLocalizedNameAndPlan() {
        let defaults = makeDefaults()
        let store = ServiceCatalogStore(
            defaults: defaults,
            bundledPayloadData: Data(samplePayload.utf8),
            remoteCatalogURL: nil
        )

        #expect(store.suggestions(for: "プレミアム").first?.id == "youtube-premium")
        #expect(store.suggestions(for: "個人").first?.id == "youtube-premium")
    }

    private var samplePayload: String {
        """
        {
          "version": 1,
          "updatedAt": "2026-02-07T00:00:00Z",
          "services": [
            { "id": "chatgpt", "name": "ChatGPT", "localizedName": "ChatGPT", "aliases": ["OpenAI ChatGPT"], "categories": ["AI", "IT"] },
            {
              "id": "youtube-premium",
              "name": "YouTube Premium",
              "localizedName": "YouTubeプレミアム",
              "aliases": [],
              "categories": ["Video"],
              "plans": [
                { "id": "individual", "name": "Individual", "localizedName": "個人" }
              ]
            },
            { "id": "x-premium", "name": "X Premium", "aliases": ["Twitter Blue"], "categories": ["Social"] }
          ]
        }
        """
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "ServiceCatalogStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
