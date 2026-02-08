import Foundation

@MainActor
final class ServiceCatalogStore: ObservableObject {
    @Published private(set) var entries: [ServiceCatalogEntry] = []
    @Published private(set) var version: Int = 0
    @Published private(set) var updatedAt: Date?
    @Published private(set) var source: ServiceCatalogSource = .bundled
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastErrorMessage: String?

    private enum Storage {
        static let cacheKey = "service_catalog.payload.v1"
        static let refreshTTL: TimeInterval = 60 * 60 * 24
    }

    private struct StoredPayload: Codable {
        let payload: ServiceCatalogPayload
        let fetchedAt: Date
    }

    private let session: URLSession
    private let defaults: UserDefaults
    private let bundle: Bundle
    private let bundledPayloadData: Data?
    private let remoteCatalogURL: URL?

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        bundledPayloadData: Data? = nil,
        remoteCatalogURL: URL? = URL(string: "https://raw.githubusercontent.com/uechikohei/subs-kun/main/SubscriptionTracker/Resources/service_catalog.json")
    ) {
        self.session = session
        self.defaults = defaults
        self.bundle = bundle
        self.bundledPayloadData = bundledPayloadData
        self.remoteCatalogURL = remoteCatalogURL

        if let cached = Self.loadCache(from: defaults) {
            apply(payload: cached.payload, source: .cache)
        } else if let bundled = loadBundledPayload() {
            apply(payload: bundled, source: .bundled)
        } else {
            entries = []
            version = 0
            updatedAt = nil
            source = .bundled
            lastErrorMessage = String(localized: "service_catalog.error.load_failed")
        }
    }

    func refreshIfNeeded(force: Bool = false) async {
        if !force, !shouldRefresh {
            return
        }
        await refresh(force: force)
    }

    func refresh(force: Bool = false) async {
        if isRefreshing {
            return
        }
        if !force, !shouldRefresh {
            return
        }
        guard let remoteCatalogURL else {
            if force {
                lastErrorMessage = String(localized: "service_catalog.error.missing_url")
            }
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let request = URLRequest(
                url: remoteCatalogURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 15
            )
            let (data, _) = try await session.data(for: request)
            let payload = try Self.decodePayload(from: data)
            apply(payload: payload, source: .remote)
            Self.saveCache(payload: payload, fetchedAt: Date(), to: defaults)
            lastErrorMessage = nil
            AppLogger.export.info("service_catalog.refresh success")
        } catch {
            if force {
                lastErrorMessage = String(localized: "service_catalog.error.refresh_failed")
            }
            AppLogger.error.error("service_catalog.refresh failed")
        }
    }

    func suggestions(for query: String, limit: Int = 8) -> [ServiceCatalogEntry] {
        let normalizedQuery = Self.normalize(query)
        guard !normalizedQuery.isEmpty else {
            return Array(entries.prefix(limit))
        }

        let scored = entries.compactMap { entry -> (entry: ServiceCatalogEntry, score: Int)? in
            let keywords = Self.keywords(for: entry)

            if keywords.contains(normalizedQuery) {
                return (entry, 300)
            }
            if keywords.contains(where: { $0.hasPrefix(normalizedQuery) }) {
                return (entry, 200)
            }
            if keywords.contains(where: { $0.contains(normalizedQuery) }) {
                return (entry, 120)
            }
            if Self.normalize(entry.categoryLabel).contains(normalizedQuery)
                || Self.normalize(entry.localizedCategoryLabel).contains(normalizedQuery) {
                return (entry, 80)
            }
            return nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.entry.displayName.localizedCaseInsensitiveCompare(rhs.entry.displayName) == .orderedAscending
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map(\.entry)
    }

    func exactMatch(for name: String) -> ServiceCatalogEntry? {
        let normalizedName = Self.normalize(name)
        guard !normalizedName.isEmpty else { return nil }

        return entries.first { entry in
            Self.keywords(for: entry).contains(normalizedName)
        }
    }

    func entry(id: String) -> ServiceCatalogEntry? {
        entries.first { $0.id == id }
    }

    var lastUpdatedText: String {
        guard let updatedAt else { return String(localized: "common.not_fetched") }
        return updatedAt.dateTimeJP()
    }

    var sourceText: String {
        source.label
    }

    var sourceURL: URL? {
        remoteCatalogURL
    }

    var genreGroups: [ServiceCatalogGenreGroup] {
        var buckets: [String: [ServiceCatalogEntry]] = [:]

        for entry in entries {
            if entry.categories.isEmpty {
                buckets[String(localized: "common.uncategorized"), default: []].append(entry)
                continue
            }

            for category in entry.categories {
                buckets[category, default: []].append(entry)
            }
        }

        return buckets
            .map { genre, values in
                ServiceCatalogGenreGroup(
                    genre: genre,
                    services: values.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                if lhs.services.count == rhs.services.count {
                    return ServiceCatalogEntry.localizedCategoryName(for: lhs.genre)
                        .localizedCaseInsensitiveCompare(ServiceCatalogEntry.localizedCategoryName(for: rhs.genre)) == .orderedAscending
                }
                return lhs.services.count > rhs.services.count
            }
    }

    var shouldRefresh: Bool {
        guard let cached = Self.loadCache(from: defaults) else {
            return false
        }
        return Date().timeIntervalSince(cached.fetchedAt) > Storage.refreshTTL
    }

    private func loadBundledPayload() -> ServiceCatalogPayload? {
        if let bundledPayloadData {
            return try? Self.decodePayload(from: bundledPayloadData)
        }

        guard let url = bundle.url(forResource: "service_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? Self.decodePayload(from: data)
    }

    private func apply(payload: ServiceCatalogPayload, source: ServiceCatalogSource) {
        entries = Self.normalizeEntries(payload.services)
        version = payload.version
        updatedAt = payload.updatedAt
        self.source = source
    }

    static func decodePayload(from data: Data) throws -> ServiceCatalogPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ServiceCatalogPayload.self, from: data)
    }

    static func normalizeEntries(_ rawEntries: [ServiceCatalogEntry]) -> [ServiceCatalogEntry] {
        var seenIDs: Set<String> = []
        var output: [ServiceCatalogEntry] = []

        for raw in rawEntries {
            let id = raw.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !id.isEmpty, !name.isEmpty, !seenIDs.contains(id) else {
                continue
            }

            let localizedName = raw.localizedName?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let aliases = uniqueOrdered(raw.aliases
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })

            let categories = uniqueOrdered(raw.categories
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })

            var plans = (raw.plans ?? [])
                .compactMap { rawPlan -> ServiceCatalogPlan? in
                    let planID = rawPlan.id.trimmingCharacters(in: .whitespacesAndNewlines)
                    let planName = rawPlan.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !planID.isEmpty, !planName.isEmpty else {
                        return nil
                    }
                    let localizedPlanName = rawPlan.localizedName?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return ServiceCatalogPlan(id: planID, name: planName, localizedName: localizedPlanName)
                }
            if plans.isEmpty, let fallbackPlans = fallbackPlansByServiceID[id] {
                plans = fallbackPlans
            }

            let resolvedLocalizedName: String?
            if let localizedName, !localizedName.isEmpty {
                resolvedLocalizedName = localizedName
            } else {
                resolvedLocalizedName = fallbackLocalizedNameByServiceID[id]
            }

            output.append(
                ServiceCatalogEntry(
                    id: id,
                    name: name,
                    localizedName: resolvedLocalizedName,
                    aliases: aliases,
                    categories: categories,
                    plans: plans.isEmpty ? nil : plans
                )
            )
            seenIDs.insert(id)
        }

        return output
    }

    private static func loadCache(from defaults: UserDefaults) -> StoredPayload? {
        guard let data = defaults.data(forKey: Storage.cacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode(StoredPayload.self, from: data)
    }

    private static func saveCache(payload: ServiceCatalogPayload, fetchedAt: Date, to defaults: UserDefaults) {
        let stored = StoredPayload(payload: payload, fetchedAt: fetchedAt)
        guard let data = try? JSONEncoder().encode(stored) else {
            return
        }
        defaults.set(data, forKey: Storage.cacheKey)
    }

    private static func keywords(for entry: ServiceCatalogEntry) -> Set<String> {
        var set: Set<String> = []
        let normalizedName = normalize(entry.name)
        if !normalizedName.isEmpty {
            set.insert(normalizedName)
        }
        let normalizedDisplayName = normalize(entry.displayName)
        if !normalizedDisplayName.isEmpty {
            set.insert(normalizedDisplayName)
        }
        for alias in entry.aliases {
            let normalizedAlias = normalize(alias)
            if !normalizedAlias.isEmpty {
                set.insert(normalizedAlias)
            }
        }
        for plan in entry.availablePlans {
            let normalizedPlanName = normalize(plan.name)
            if !normalizedPlanName.isEmpty {
                set.insert(normalizedPlanName)
            }
            let normalizedPlanDisplayName = normalize(plan.displayName)
            if !normalizedPlanDisplayName.isEmpty {
                set.insert(normalizedPlanDisplayName)
            }
        }
        return set
    }

    private static func normalize(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []

        for value in values {
            if seen.contains(value) {
                continue
            }
            seen.insert(value)
            output.append(value)
        }

        return output
    }

    private static let fallbackLocalizedNameByServiceID: [String: String] = [
        "amazon-prime": "Amazonプライム",
        "chatgpt": "ChatGPT",
        "disney-plus": "ディズニープラス",
        "netflix": "Netflix",
        "spotify": "Spotify",
        "youtube-premium": "YouTubeプレミアム"
    ]

    private static let fallbackPlansByServiceID: [String: [ServiceCatalogPlan]] = [
        "chatgpt": [
            ServiceCatalogPlan(id: "free", name: "Free", localizedName: "無料"),
            ServiceCatalogPlan(id: "plus", name: "Plus", localizedName: "Plus"),
            ServiceCatalogPlan(id: "pro", name: "Pro", localizedName: "Pro")
        ],
        "netflix": [
            ServiceCatalogPlan(id: "ad-supported", name: "Ad-Supported", localizedName: "広告つきスタンダード"),
            ServiceCatalogPlan(id: "standard", name: "Standard", localizedName: "スタンダード"),
            ServiceCatalogPlan(id: "premium", name: "Premium", localizedName: "プレミアム")
        ],
        "youtube-premium": [
            ServiceCatalogPlan(id: "individual", name: "Individual", localizedName: "個人"),
            ServiceCatalogPlan(id: "family", name: "Family", localizedName: "ファミリー"),
            ServiceCatalogPlan(id: "student", name: "Student", localizedName: "学生")
        ],
        "spotify": [
            ServiceCatalogPlan(id: "individual", name: "Individual", localizedName: "Individual"),
            ServiceCatalogPlan(id: "duo", name: "Duo", localizedName: "Duo"),
            ServiceCatalogPlan(id: "family", name: "Family", localizedName: "Family"),
            ServiceCatalogPlan(id: "student", name: "Student", localizedName: "Student")
        ],
        "amazon-prime": [
            ServiceCatalogPlan(id: "monthly", name: "Monthly", localizedName: "月間プラン"),
            ServiceCatalogPlan(id: "yearly", name: "Yearly", localizedName: "年間プラン")
        ]
    ]
}
