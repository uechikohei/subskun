import Foundation
import SwiftData

@Model
final class Subscription {
    @Attribute(.unique) var id: UUID
    var name: String
    var serviceCatalogID: String
    var planName: String
    var amount: Int
    var currency: String
    private var statusRaw: String
    var category: String
    private var categoryTagsRaw: String = ""
    var firstBillingDate: Date
    var cancellationDate: Date?
    private var billingCycleTypeRaw: String
    var billingInterval: Int
    var customDaysInterval: Int?
    private var selectedMonthsRaw: String = ""
    private var selectedYearMonthsRaw: String = ""
    private var historicalBilledYearMonthsRaw: String = ""
    var memo: String
    var paymentMethod: String
    var referenceURL: String
    var attachmentImageData: Data?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BillingEvent.subscription)
    var events: [BillingEvent]

    init(
        id: UUID = UUID(),
        name: String,
        serviceCatalogID: String = "",
        planName: String = "",
        amount: Int,
        currency: String = "JPY",
        status: SubscriptionStatus = .active,
        category: String = "",
        categoryTags: [String] = [],
        firstBillingDate: Date,
        cancellationDate: Date? = nil,
        billingCycleType: BillingCycleType = .monthly,
        billingInterval: Int = 1,
        customDaysInterval: Int? = nil,
        selectedMonths: [Int] = [],
        selectedYearMonths: [String] = [],
        historicalBilledYearMonths: [String] = [],
        memo: String = "",
        paymentMethod: String = "",
        referenceURL: String = "",
        attachmentImageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        events: [BillingEvent] = []
    ) {
        self.id = id
        self.name = name
        self.serviceCatalogID = serviceCatalogID
        self.planName = planName
        self.amount = amount
        self.currency = currency
        self.statusRaw = status.rawValue
        let normalizedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategoryTags = Self.uniqueNormalizedTags(categoryTags)
        self.category = normalizedCategoryTags.first ?? normalizedCategory
        self.categoryTagsRaw = normalizedCategoryTags.joined(separator: ",")
        self.firstBillingDate = firstBillingDate
        self.cancellationDate = cancellationDate
        self.billingCycleTypeRaw = billingCycleType.rawValue
        self.billingInterval = max(1, billingInterval)
        self.customDaysInterval = customDaysInterval
        self.selectedMonthsRaw = ""
        self.selectedYearMonthsRaw = ""
        self.historicalBilledYearMonthsRaw = ""
        self.memo = memo
        self.paymentMethod = paymentMethod
        self.referenceURL = referenceURL
        self.attachmentImageData = attachmentImageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.events = events
        self.selectedMonths = selectedMonths
        self.selectedYearMonths = selectedYearMonths
        self.historicalBilledYearMonths = historicalBilledYearMonths
    }

    var status: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var billingCycleType: BillingCycleType {
        get { BillingCycleType(rawValue: billingCycleTypeRaw) ?? .monthly }
        set { billingCycleTypeRaw = newValue.rawValue }
    }

    var selectedMonths: [Int] {
        get {
            let parsed = selectedMonthsRaw
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { (1 ... 12).contains($0) }

            var seen: Set<Int> = []
            return parsed
                .filter { seen.insert($0).inserted }
                .sorted()
        }
        set {
            let normalized = newValue
                .filter { (1 ... 12).contains($0) }
                .sorted()
            let unique = Array(Set(normalized)).sorted()
            selectedMonthsRaw = unique.map(String.init).joined(separator: ",")
        }
    }

    var categoryTags: [String] {
        get {
            let parsed = categoryTagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var seen: Set<String> = []
            let unique = parsed.filter { seen.insert($0).inserted }
            if !unique.isEmpty {
                return unique
            }

            let fallback = category.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? [] : [fallback]
        }
        set {
            let normalized = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var seen: Set<String> = []
            let unique = normalized.filter { seen.insert($0).inserted }
            categoryTagsRaw = unique.joined(separator: ",")
            category = unique.first ?? ""
        }
    }

    var selectedYearMonths: [String] {
        get {
            let parsed = selectedYearMonthsRaw
                .split(separator: ",")
                .compactMap { Self.parseYearMonth(String($0)) }

            var seen: Set<String> = []
            return parsed
                .map { Self.yearMonthKey(year: $0.year, month: $0.month) }
                .filter { seen.insert($0).inserted }
                .sorted(by: Self.yearMonthLessThan)
        }
        set {
            let normalized = newValue
                .compactMap { Self.parseYearMonth($0) }
                .map { Self.yearMonthKey(year: $0.year, month: $0.month) }
                .sorted(by: Self.yearMonthLessThan)

            var seen: Set<String> = []
            let unique = normalized.filter { seen.insert($0).inserted }
            selectedYearMonthsRaw = unique.joined(separator: ",")
        }
    }

    var historicalBilledYearMonths: [String] {
        get {
            let parsed = historicalBilledYearMonthsRaw
                .split(separator: ",")
                .compactMap { Self.parseYearMonth(String($0)) }

            var seen: Set<String> = []
            return parsed
                .map { Self.yearMonthKey(year: $0.year, month: $0.month) }
                .filter { seen.insert($0).inserted }
                .sorted(by: Self.yearMonthLessThan)
        }
        set {
            let normalized = newValue
                .compactMap { Self.parseYearMonth($0) }
                .map { Self.yearMonthKey(year: $0.year, month: $0.month) }
                .sorted(by: Self.yearMonthLessThan)

            var seen: Set<String> = []
            let unique = normalized.filter { seen.insert($0).inserted }
            historicalBilledYearMonthsRaw = unique.joined(separator: ",")
        }
    }

    private static func parseYearMonth(_ raw: String) -> (year: Int, month: Int)? {
        let components = raw.split(separator: "-", omittingEmptySubsequences: true)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              (1 ... 12).contains(month),
              (1900 ... 3000).contains(year) else {
            return nil
        }
        return (year, month)
    }

    private static func uniqueNormalizedTags(_ tags: [String]) -> [String] {
        let normalized = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen: Set<String> = []
        return normalized.filter { seen.insert($0).inserted }
    }

    private static func yearMonthKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    private static func yearMonthLessThan(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = parseYearMonth(lhs), let right = parseYearMonth(rhs) else {
            return lhs < rhs
        }
        if left.year != right.year {
            return left.year < right.year
        }
        return left.month < right.month
    }
}
