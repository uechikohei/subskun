import Foundation
import Testing
@testable import SubsKun

struct SummaryServiceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    @Test
    func monthlyTotalsRespectPausedFlag() {
        let service = SummaryService(calendar: calendar)
        let now = date(2026, 2, 7)

        let activeSubscription = Subscription(
            name: "Active",
            amount: 1000,
            status: .active,
            firstBillingDate: date(2025, 1, 1),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let pausedSubscription = Subscription(
            name: "Paused",
            amount: 300,
            status: .paused,
            firstBillingDate: date(2025, 1, 1),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let activeProjected = BillingEvent(
            subscription: activeSubscription,
            billedAt: date(2026, 2, 10),
            amount: 1000,
            eventType: .projected
        )
        let activeConfirmed = BillingEvent(
            subscription: activeSubscription,
            billedAt: date(2026, 2, 5),
            amount: 500,
            eventType: .confirmed
        )
        let pausedProjected = BillingEvent(
            subscription: pausedSubscription,
            billedAt: date(2026, 2, 20),
            amount: 300,
            eventType: .projected
        )

        let events = [activeProjected, activeConfirmed, pausedProjected]

        let excluded = service.buildSummary(
            from: events,
            now: now,
            includePaused: false,
            convertToJPY: { amount, _ in amount }
        )
        #expect(excluded.monthProjectedTotal == 1000)
        #expect(excluded.monthConfirmedTotal == 500)
        #expect(excluded.unconvertedEventCount == 0)

        let included = service.buildSummary(
            from: events,
            now: now,
            includePaused: true,
            convertToJPY: { amount, _ in amount }
        )
        #expect(included.monthProjectedTotal == 1300)
        #expect(included.monthConfirmedTotal == 500)
        #expect(included.yearProjectedTotal == 1300)
        #expect(included.upcomingEvents.count == 2)
        #expect(included.unconvertedEventCount == 0)
    }

    @Test
    func hierarchyGroupsByCategoryServiceAndPlan() {
        let service = SummaryService(calendar: calendar)
        let now = date(2026, 2, 7)

        let plusSubscription = Subscription(
            name: "ChatGPT",
            serviceCatalogID: "chatgpt",
            planName: "Plus",
            amount: 20,
            currency: "USD",
            status: .active,
            category: "AI",
            firstBillingDate: date(2025, 1, 1),
            billingCycleType: .monthly,
            billingInterval: 1
        )
        let proSubscription = Subscription(
            name: "ChatGPT",
            serviceCatalogID: "chatgpt",
            planName: "Pro",
            amount: 200,
            currency: "USD",
            status: .active,
            category: "AI",
            firstBillingDate: date(2025, 1, 1),
            billingCycleType: .monthly,
            billingInterval: 1
        )

        let plusEvent = BillingEvent(
            subscription: plusSubscription,
            billedAt: date(2026, 2, 2),
            amount: 20,
            currency: "USD",
            eventType: .projected
        )
        let proEvent = BillingEvent(
            subscription: proSubscription,
            billedAt: date(2026, 2, 3),
            amount: 200,
            currency: "USD",
            eventType: .projected
        )

        let metrics = service.buildSummary(
            from: [plusEvent, proEvent],
            now: now,
            includePaused: true,
            convertToJPY: { amount, _ in amount * 10 }
        )

        #expect(metrics.monthProjectedTotal == 2200)
        #expect(metrics.monthProjectedHierarchy.count == 1)
        #expect(metrics.monthProjectedHierarchy.first?.category == "AI")
        #expect(metrics.monthProjectedHierarchy.first?.services.count == 1)
        #expect(metrics.monthProjectedHierarchy.first?.services.first?.serviceName == "ChatGPT")
        #expect(metrics.monthProjectedHierarchy.first?.services.first?.plans.count == 2)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
