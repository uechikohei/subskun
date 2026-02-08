import Foundation
import SwiftUI

struct SubscriptionRowView: View {
    let subscription: Subscription
    let nextBillingDate: Date?
    let convertedYenAmount: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(subscription.name)
                    .font(.headline)
                    .lineLimit(1)
                if !subscription.planName.isEmpty {
                    Text(subscription.planName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    StatusBadge(text: subscription.status.label, color: statusColor)
                    if !subscription.category.isEmpty {
                        Text(subscription.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(subscription.amount.currencyString(currencyCode: subscription.currency))
                    .font(.headline)
                if subscription.currency.uppercased() != "JPY", let convertedYenAmount {
                    Text(String(
                        format: String(localized: "common.approx_amount_format"),
                        locale: Locale.autoupdatingCurrent,
                        convertedYenAmount.yenString()
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let nextBillingDate {
                    Text(String(
                        format: String(localized: "subscription.row.next_billing_format"),
                        locale: Locale.autoupdatingCurrent,
                        nextBillingDate.shortJP()
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "subscription.row.no_next_billing"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch subscription.status {
        case .active:
            return .green
        case .paused:
            return .orange
        case .cancelled:
            return .gray
        }
    }
}
