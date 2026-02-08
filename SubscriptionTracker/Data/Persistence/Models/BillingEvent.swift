import Foundation
import SwiftData

@Model
final class BillingEvent {
    @Attribute(.unique) var id: UUID
    var billedAt: Date
    var amount: Int
    var currency: String
    private var eventTypeRaw: String
    var isAmountOverridden: Bool
    var memo: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship var subscription: Subscription?

    init(
        id: UUID = UUID(),
        subscription: Subscription? = nil,
        billedAt: Date,
        amount: Int,
        currency: String = "JPY",
        eventType: BillingEventType = .projected,
        isAmountOverridden: Bool = false,
        memo: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.subscription = subscription
        self.billedAt = billedAt
        self.amount = amount
        self.currency = currency
        self.eventTypeRaw = eventType.rawValue
        self.isAmountOverridden = isAmountOverridden
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var eventType: BillingEventType {
        get { BillingEventType(rawValue: eventTypeRaw) ?? .projected }
        set { eventTypeRaw = newValue.rawValue }
    }
}
