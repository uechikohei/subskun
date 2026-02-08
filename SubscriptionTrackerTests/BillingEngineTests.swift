import Foundation
import Testing
@testable import SubsKun

struct BillingEngineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    @Test
    func monthlyEndOfMonthAnchoring() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Netflix",
            amount: 1200,
            status: .active,
            firstBillingDate: date(2025, 1, 31),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2025, 4, 30),
            confirmedDates: []
        )

        #expect(strings(dates) == [
            "2025-01-31",
            "2025-02-28",
            "2025-03-31",
            "2025-04-30"
        ])
    }

    @Test
    func yearlyLeapYearAnchoring() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Yearly Service",
            amount: 5000,
            status: .active,
            firstBillingDate: date(2024, 2, 29),
            billingCycleType: .yearly,
            billingInterval: 1
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2024, 1, 1),
            rangeEnd: date(2028, 12, 31),
            confirmedDates: []
        )

        #expect(strings(dates) == [
            "2024-02-29",
            "2025-02-28",
            "2026-02-28",
            "2027-02-28",
            "2028-02-29"
        ])
    }

    @Test
    func cancelledStopsGenerationAfterCancellationDate() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Cancelled",
            amount: 1000,
            status: .cancelled,
            firstBillingDate: date(2025, 1, 10),
            cancellationDate: date(2025, 3, 10),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2025, 12, 31),
            confirmedDates: []
        )

        #expect(strings(dates) == [
            "2025-01-10",
            "2025-02-10",
            "2025-03-10"
        ])
    }

    @Test
    func pausedDoesNotGenerateProjectedDatesAndHasNoNextBillingDate() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Paused",
            amount: 1000,
            status: .paused,
            firstBillingDate: date(2025, 1, 10),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2025, 12, 31),
            confirmedDates: []
        )

        #expect(dates.isEmpty)
        #expect(engine.nextBillingDate(for: subscription, from: date(2025, 2, 1)) == nil)
    }

    @Test
    func confirmedDatesAreExcludedFromProjectedGeneration() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Service",
            amount: 900,
            status: .active,
            firstBillingDate: date(2025, 1, 10),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let confirmed = Set([date(2025, 2, 10)])

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2025, 3, 31),
            confirmedDates: confirmed
        )

        #expect(strings(dates) == [
            "2025-01-10",
            "2025-03-10"
        ])
    }

    @Test
    func oneTimeCycleGeneratesOnlyAnchorDate() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "One Time",
            amount: 1500,
            status: .active,
            firstBillingDate: date(2025, 1, 10),
            billingCycleType: .oneTime,
            billingInterval: 1
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2025, 12, 31),
            confirmedDates: []
        )

        #expect(strings(dates) == ["2025-01-10"])
    }

    @Test
    func monthlyIntervalSupportsSkipMonthsPattern() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Skip Months",
            amount: 1000,
            status: .active,
            firstBillingDate: date(2025, 1, 10),
            billingCycleType: .monthly,
            billingInterval: 3
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2025, 9, 30),
            confirmedDates: []
        )

        #expect(strings(dates) == [
            "2025-01-10",
            "2025-04-10",
            "2025-07-10"
        ])
    }

    @Test
    func selectedMonthsSupportsFlexibleMonthlyPattern() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Flexible Months",
            amount: 1800,
            status: .active,
            firstBillingDate: date(2025, 1, 31),
            billingCycleType: .selectedMonths,
            billingInterval: 1,
            selectedMonths: [1, 3, 7, 10]
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2025, 12, 31),
            confirmedDates: []
        )

        #expect(strings(dates) == [
            "2025-01-31",
            "2025-03-31",
            "2025-07-31",
            "2025-10-31"
        ])
    }

    @Test
    func calendarMonthsSupportsYearMonthSpecificSchedule() {
        let engine = BillingEngine(calendar: calendar)
        let subscription = Subscription(
            name: "Variable Calendar Months",
            amount: 2200,
            status: .active,
            firstBillingDate: date(2025, 1, 31),
            billingCycleType: .calendarMonths,
            billingInterval: 1,
            selectedYearMonths: ["2025-01", "2025-03", "2025-07", "2025-10", "2026-02"]
        )

        let dates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: date(2025, 1, 1),
            rangeEnd: date(2026, 12, 31),
            confirmedDates: []
        )

        #expect(strings(dates) == [
            "2025-01-31",
            "2025-03-31",
            "2025-07-31",
            "2025-10-31",
            "2026-02-28"
        ])
    }

    private func strings(_ dates: [Date]) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return dates.map { formatter.string(from: $0) }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
