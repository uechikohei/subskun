import Foundation

struct ExchangeRateSnapshot: Codable, Sendable {
    let baseCode: String
    let rates: [String: Double]
    let lastUpdatedAt: Date
    let nextUpdateAt: Date

    func convert(amount: Int, from sourceCurrency: String, to targetCurrency: String) -> Int? {
        let source = sourceCurrency.uppercased()
        let target = targetCurrency.uppercased()

        if source == target {
            return amount
        }

        let normalizedRates = rates

        let sourceRate = source == baseCode ? 1.0 : normalizedRates[source]
        let targetRate = target == baseCode ? 1.0 : normalizedRates[target]

        guard let sourceRate, sourceRate > 0,
              let targetRate, targetRate > 0 else {
            return nil
        }

        let baseAmount = Double(amount) / sourceRate
        let converted = baseAmount * targetRate
        return Int(converted.rounded())
    }

    func rate(from sourceCurrency: String, to targetCurrency: String) -> Double? {
        let source = sourceCurrency.uppercased()
        let target = targetCurrency.uppercased()

        if source == target {
            return 1.0
        }

        let sourceRate = source == baseCode ? 1.0 : rates[source]
        let targetRate = target == baseCode ? 1.0 : rates[target]

        guard let sourceRate, sourceRate > 0,
              let targetRate, targetRate > 0 else {
            return nil
        }

        return targetRate / sourceRate
    }
}

@MainActor
final class ExchangeRateStore: ObservableObject {
    @Published private(set) var snapshot: ExchangeRateSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastErrorMessage: String?

    private enum Storage {
        static let cacheKey = "exchange_rate.snapshot.v1"
        static let cacheTTL: TimeInterval = 60 * 60 * 6
    }

    private let endpointURL = URL(string: "https://open.er-api.com/v6/latest/USD")!
    private let session: URLSession
    private let defaults: UserDefaults

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
        self.snapshot = Self.loadCache(from: defaults)
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

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let request = URLRequest(url: endpointURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(ExchangeRateAPIResponse.self, from: data)

            guard response.result.lowercased() == "success" else {
                throw ExchangeRateError.invalidResponse
            }

            let rateSnapshot = ExchangeRateSnapshot(
                baseCode: response.baseCode.uppercased(),
                rates: response.rates.reduce(into: [String: Double]()) { partialResult, pair in
                    partialResult[pair.key.uppercased()] = pair.value
                },
                lastUpdatedAt: Date(timeIntervalSince1970: response.lastUpdateUnix),
                nextUpdateAt: Date(timeIntervalSince1970: response.nextUpdateUnix)
            )

            snapshot = rateSnapshot
            lastErrorMessage = nil
            Self.saveCache(rateSnapshot, to: defaults)

            AppLogger.export.info("exchange_rate.refresh success")
        } catch {
            lastErrorMessage = String(localized: "exchange_rate.error.fetch_failed")
            AppLogger.error.error("exchange_rate.refresh failed")
        }
    }

    func convert(amount: Int, from sourceCurrency: String, to targetCurrency: String) -> Int? {
        let source = sourceCurrency.uppercased()
        let target = targetCurrency.uppercased()

        if source == target {
            return amount
        }

        guard let snapshot else {
            return nil
        }

        return snapshot.convert(amount: amount, from: source, to: target)
    }

    func convertToJPY(amount: Int, currency: String) -> Int? {
        convert(amount: amount, from: currency, to: "JPY")
    }

    func rate(from sourceCurrency: String, to targetCurrency: String) -> Double? {
        guard let snapshot else {
            return nil
        }
        return snapshot.rate(from: sourceCurrency, to: targetCurrency)
    }

    var lastUpdatedText: String {
        guard let snapshot else {
            return String(localized: "common.not_fetched")
        }
        return snapshot.lastUpdatedAt.dateTimeJP()
    }

    var sourceAttributionURL: URL {
        URL(string: "https://www.exchangerate-api.com")!
    }

    private var shouldRefresh: Bool {
        guard let snapshot else { return true }

        let now = Date()
        if now >= snapshot.nextUpdateAt {
            return true
        }

        return now.timeIntervalSince(snapshot.lastUpdatedAt) > Storage.cacheTTL
    }

    private static func loadCache(from defaults: UserDefaults) -> ExchangeRateSnapshot? {
        guard let data = defaults.data(forKey: Storage.cacheKey) else {
            return nil
        }

        return try? JSONDecoder().decode(ExchangeRateSnapshot.self, from: data)
    }

    private static func saveCache(_ snapshot: ExchangeRateSnapshot, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        defaults.set(data, forKey: Storage.cacheKey)
    }
}

private struct ExchangeRateAPIResponse: Decodable {
    let result: String
    let baseCode: String
    let rates: [String: Double]
    let lastUpdateUnix: TimeInterval
    let nextUpdateUnix: TimeInterval

    enum CodingKeys: String, CodingKey {
        case result
        case baseCode = "base_code"
        case rates
        case lastUpdateUnix = "time_last_update_unix"
        case nextUpdateUnix = "time_next_update_unix"
    }
}

enum ExchangeRateError: Error {
    case invalidResponse
}
