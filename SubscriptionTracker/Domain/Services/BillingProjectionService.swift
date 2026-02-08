import Foundation
import SwiftData

struct BillingProjectionService {
    private let engine: BillingEngine
    private let calendar: Calendar

    init(engine: BillingEngine = BillingEngine(), calendar: Calendar = .current) {
        self.engine = engine
        self.calendar = calendar
    }

    func regenerate(
        for subscription: Subscription,
        in context: ModelContext,
        settings: SettingsSnapshot,
        now: Date = Date()
    ) {
        let base = calendar.startOfDay(for: now)
        let rangeStart = calendar.date(byAdding: .month, value: -settings.pastMonths, to: base) ?? base
        let rangeEnd = calendar.date(byAdding: .month, value: settings.futureMonths, to: base) ?? base

        let confirmedDates = Set(subscription.events
            .filter { $0.eventType == .confirmed }
            .map { calendar.startOfDay(for: $0.billedAt) })

        let oldProjected = subscription.events.filter { $0.eventType == .projected }
        oldProjected.forEach { context.delete($0) }

        let projectedDates = engine.generateProjectedDates(
            for: subscription,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            confirmedDates: confirmedDates
        )

        for billedAt in projectedDates {
            let event = BillingEvent(
                subscription: subscription,
                billedAt: billedAt,
                amount: subscription.amount,
                currency: subscription.currency,
                eventType: .projected,
                isAmountOverridden: false,
                memo: ""
            )
            context.insert(event)
        }

        subscription.updatedAt = now
    }

    func regenerateAll(
        subscriptions: [Subscription],
        in context: ModelContext,
        settings: SettingsSnapshot,
        now: Date = Date()
    ) {
        for subscription in subscriptions {
            regenerate(for: subscription, in: context, settings: settings, now: now)
        }
    }
}
