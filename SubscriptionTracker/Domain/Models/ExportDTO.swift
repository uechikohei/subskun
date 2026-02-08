import Foundation

struct ExportEnvelopeDTO: Codable {
    let schemaVersion: String
    let exportedAt: String
    let settings: ExportSettingsDTO
    let subscriptions: [ExportSubscriptionDTO]
    let billingEvents: [ExportBillingEventDTO]
}

struct ExportSettingsDTO: Codable {
    let timezone: String
    let historyRange: ExportHistoryRangeDTO
}

struct ExportHistoryRangeDTO: Codable {
    let pastMonths: Int
    let futureMonths: Int
}

struct ExportSubscriptionDTO: Codable {
    let id: String
    let name: String
    let serviceCatalogID: String?
    let planName: String?
    let status: String
    let category: String
    let amount: Int
    let currency: String
    let firstBillingDate: String
    let cancellationDate: String?
    let billingCycle: ExportBillingCycleDTO
    let memo: String
    let createdAt: String
    let updatedAt: String
}

struct ExportBillingCycleDTO: Codable {
    let type: String
    let interval: Int
    let customDaysInterval: Int?
    let selectedMonths: [Int]?
    let selectedYearMonths: [String]?
    let historicalBilledYearMonths: [String]?
}

struct ExportBillingEventDTO: Codable {
    let id: String
    let subscriptionId: String
    let billedAt: String
    let amount: Int
    let currency: String
    let eventType: String
    let isAmountOverridden: Bool
    let memo: String
    let createdAt: String
    let updatedAt: String
}
