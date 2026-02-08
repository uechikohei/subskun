import Foundation
import SwiftData
import SwiftUI

struct BillingEventEditView: View {
    let event: BillingEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var amount: Int
    @State private var memo: String
    @State private var errorMessage: String?

    init(event: BillingEvent) {
        self.event = event
        _amount = State(initialValue: event.amount)
        _memo = State(initialValue: event.memo)
    }

    var body: some View {
        Form {
            Section(String(localized: "billing_event.edit.section")) {
                Text(String(
                    format: String(localized: "billing_event.edit.billed_at_format"),
                    locale: Locale.autoupdatingCurrent,
                    event.billedAt.shortJP()
                ))
                TextField(String(localized: "common.amount"), value: $amount, format: .number)
                    .keyboardType(.numberPad)
                TextEditor(text: $memo)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle(String(localized: "billing_event.edit.navigation_title"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    save()
                }
                .disabled(amount < 0)
            }
        }
        .alert(String(localized: "common.error"), isPresented: errorAlertBinding) {
            Button(String(localized: "common.ok"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? String(localized: "billing_event.edit.error.save_failed"))
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )
    }

    private func save() {
        guard amount >= 0 else { return }

        event.amount = amount
        event.memo = memo
        if let baseAmount = event.subscription?.amount {
            event.isAmountOverridden = amount != baseAmount
        }
        event.updatedAt = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = String(localized: "billing_event.edit.error.save_failed")
            AppLogger.error.error("event.edit failed")
        }
    }
}
