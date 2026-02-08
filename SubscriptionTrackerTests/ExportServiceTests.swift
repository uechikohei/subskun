import Foundation
import Testing
@testable import SubsKun

struct ExportServiceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    @Test
    func jsonContainsSchemaAndScopePayload() throws {
        let service = ExportService(calendar: calendar)
        let subscription = Subscription(
            name: "Netflix",
            amount: 1200,
            status: .active,
            firstBillingDate: date(2025, 1, 10),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let event = BillingEvent(
            subscription: subscription,
            billedAt: date(2026, 2, 10),
            amount: 1200,
            eventType: .projected
        )

        let data = try service.makeJSONData(
            scope: .both,
            subscriptions: [subscription],
            events: [event],
            settings: SettingsSnapshot(defaultCurrency: "JPY", pastMonths: 6, futureMonths: 12, includePausedInSummary: false),
            now: date(2026, 2, 7)
        )

        let decoded = try JSONDecoder().decode(ExportEnvelopeDTO.self, from: data)

        #expect(decoded.schemaVersion == "1.0")
        #expect(decoded.subscriptions.count == 1)
        #expect(decoded.billingEvents.count == 1)
        #expect(decoded.subscriptions.first?.name == "Netflix")
        #expect(decoded.billingEvents.first?.eventType == "projected")
    }

    @Test
    func csvEscapesCommaQuoteAndNewline() throws {
        let service = ExportService(calendar: calendar)
        let subscription = Subscription(
            name: "Service,Plus",
            amount: 2500,
            status: .active,
            category: "media",
            firstBillingDate: date(2025, 1, 1),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let event = BillingEvent(
            subscription: subscription,
            billedAt: date(2026, 1, 1),
            amount: 2500,
            eventType: .confirmed,
            memo: "line1\nline\"2"
        )

        let data = try service.makeCSVData(scope: .historyOnly, subscriptions: [subscription], events: [event])
        let csv = String(decoding: data, as: UTF8.self)

        #expect(csv.contains("\"Service,Plus\""))
        #expect(csv.contains("\"line1\nline\"\"2\""))
    }

    @Test
    func exportIncludesSelectedYearMonthsForCalendarMode() throws {
        let service = ExportService(calendar: calendar)
        let subscription = Subscription(
            name: "ChatGPT Plus",
            serviceCatalogID: "chatgpt",
            planName: "Plus",
            amount: 20,
            currency: "USD",
            status: .active,
            firstBillingDate: date(2025, 1, 31),
            billingCycleType: .calendarMonths,
            billingInterval: 1,
            selectedYearMonths: ["2025-01", "2025-03", "2025-07"],
            historicalBilledYearMonths: ["2024-10", "2025-02"]
        )

        let data = try service.makeJSONData(
            scope: .definitionsOnly,
            subscriptions: [subscription],
            events: [],
            settings: SettingsSnapshot(defaultCurrency: "JPY", pastMonths: 6, futureMonths: 12, includePausedInSummary: false),
            now: date(2026, 2, 7)
        )

        let decoded = try JSONDecoder().decode(ExportEnvelopeDTO.self, from: data)
        #expect(decoded.subscriptions.count == 1)
        #expect(decoded.subscriptions.first?.serviceCatalogID == "chatgpt")
        #expect(decoded.subscriptions.first?.planName == "Plus")
        #expect(decoded.subscriptions.first?.billingCycle.selectedYearMonths == ["2025-01", "2025-03", "2025-07"])
        #expect(decoded.subscriptions.first?.billingCycle.historicalBilledYearMonths == ["2024-10", "2025-02"])

        let csvData = try service.makeCSVData(scope: .definitionsOnly, subscriptions: [subscription], events: [])
        let csv = String(decoding: csvData, as: UTF8.self)
        #expect(csv.contains("selected_year_months"))
        #expect(csv.contains("historical_billed_year_months"))
        #expect(csv.contains("service_catalog_id"))
        #expect(csv.contains("plan_name"))
        #expect(csv.contains("chatgpt"))
        #expect(csv.contains("Plus"))
        #expect(csv.contains("2025-01|2025-03|2025-07"))
        #expect(csv.contains("2024-10|2025-02"))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
