import Foundation
import SwiftData
import SwiftUI
import UIKit

struct SubscriptionDetailView: View {
    let subscription: Subscription

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var exchangeRates: ExchangeRateStore

    @State private var historyFilter: HistoryFilter = .all
    @State private var editingEvent: BillingEvent?
    @State private var isShowingEditForm = false
    @State private var isShowingExport = false
    @State private var isShowingDeleteDialog = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section(String(localized: "subscription.detail.section.basic")) {
                infoRow(title: String(localized: "subscription.field.service_name"), value: subscription.name)
                if !subscription.planName.isEmpty {
                    infoRow(title: String(localized: "subscription.field.plan"), value: subscription.planName)
                }
                infoRow(title: String(localized: "subscription.field.status"), value: subscription.status.label)
                infoRow(title: String(localized: "subscription.field.amount"), value: subscription.amount.currencyString(currencyCode: subscription.currency))
                if let converted = convertedYen(amount: subscription.amount, currency: subscription.currency),
                   subscription.currency.uppercased() != "JPY" {
                    infoRow(title: String(localized: "subscription.field.jpy_reference"), value: converted.yenString())
                }
                infoRow(title: String(localized: "subscription.field.currency"), value: subscription.currency)
                if subscription.categoryTags.isEmpty {
                    infoRow(title: String(localized: "subscription.field.category"), value: String(localized: "common.hyphen"))
                } else {
                    infoRow(title: String(localized: "subscription.field.category"), value: subscription.categoryTags.joined(separator: ", "))
                }
                infoRow(title: String(localized: "subscription.field.first_billing_date"), value: subscription.firstBillingDate.shortJP())
                if let cancellationDate = subscription.cancellationDate {
                    infoRow(title: String(localized: "subscription.field.cancellation_date"), value: cancellationDate.shortJP())
                }
                infoRow(title: String(localized: "subscription.field.billing_cycle"), value: cycleDescription)
                if !subscription.paymentMethod.isEmpty {
                    infoRow(title: String(localized: "subscription.field.payment_method"), value: subscription.paymentMethod)
                }
                if !subscription.referenceURL.isEmpty {
                    if let url = URL(string: subscription.referenceURL),
                       let scheme = url.scheme,
                       scheme.lowercased().hasPrefix("http") {
                        Link(destination: url) {
                            HStack {
                                Text(String(localized: "subscription.field.url"))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(subscription.referenceURL)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        infoRow(title: String(localized: "subscription.field.url"), value: subscription.referenceURL)
                    }
                }
                if let confirmedTotalSummary {
                    infoRow(title: String(localized: "subscription.field.confirmed_total"), value: confirmedTotalSummary)
                }
                if !subscription.memo.isEmpty {
                    infoRow(title: String(localized: "subscription.field.memo"), value: subscription.memo)
                }
            }

            if let imageData = subscription.attachmentImageData,
               let image = UIImage(data: imageData) {
                Section(String(localized: "subscription.field.image")) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Section {
                Picker(String(localized: "history.filter"), selection: $historyFilter) {
                    ForEach(HistoryFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "subscription.detail.section.billing_history")) {
                if filteredEvents.isEmpty {
                    Text(String(localized: "subscription.detail.history.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredEvents) { event in
                        eventRow(event)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    editingEvent = event
                                } label: {
                                    Label(String(localized: "common.edit"), systemImage: "pencil")
                                }
                                .tint(.orange)

                                if event.eventType == .projected {
                                    Button {
                                        confirmEvent(event)
                                    } label: {
                                        Label(String(localized: "event_type.confirmed"), systemImage: "checkmark.circle")
                                    }
                                    .tint(.green)
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(subscription.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Button {
                    isShowingEditForm = true
                } label: {
                    Image(systemName: "pencil")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    isShowingDeleteDialog = true
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $isShowingEditForm) {
            NavigationStack {
                SubscriptionEditView(subscription: subscription)
            }
        }
        .sheet(item: $editingEvent) { event in
            NavigationStack {
                BillingEventEditView(event: event)
            }
        }
        .sheet(isPresented: $isShowingExport) {
            NavigationStack {
                ExportView(initialScope: .historyOnly)
            }
        }
        .confirmationDialog(String(localized: "subscription.detail.delete.confirm_title"), isPresented: $isShowingDeleteDialog, titleVisibility: .visible) {
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteSubscription()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "subscription.detail.delete.confirm_message"))
        }
        .alert(String(localized: "common.error"), isPresented: errorAlertBinding) {
            Button(String(localized: "common.ok"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? String(localized: "common.unknown_error"))
        }
        .onAppear {
            regenerateProjectedEvents()
            Task {
                await exchangeRates.refreshIfNeeded()
            }
        }
    }

    private var cycleDescription: String {
        switch subscription.billingCycleType {
        case .monthly:
            let skipMonths = max(0, subscription.billingInterval - 1)
            if skipMonths == 0 {
                return String(localized: "subscription.cycle.monthly.every_month")
            }
            let format = String(localized: "subscription.cycle.monthly.skip_format")
            return String(format: format, locale: Locale.autoupdatingCurrent, skipMonths)
        case .yearly:
            let format = String(localized: "subscription.cycle.yearly.format")
            return String(format: format, locale: Locale.autoupdatingCurrent, subscription.billingInterval)
        case .selectedMonths:
            let months = subscription.selectedMonths
            if months.isEmpty {
                return String(localized: "subscription.cycle.selected_months.empty")
            }
            let joined = months
                .map { String(format: String(localized: "common.month_number_short"), locale: Locale.autoupdatingCurrent, $0) }
                .joined(separator: ", ")
            let format = String(localized: "subscription.cycle.selected_months.format")
            return String(format: format, locale: Locale.autoupdatingCurrent, joined)
        case .calendarMonths:
            let yearMonths = subscription.selectedYearMonths
            if yearMonths.isEmpty {
                return String(localized: "subscription.cycle.calendar_months.empty")
            }
            let joined = yearMonths
                .map { formatYearMonth($0) }
                .joined(separator: ", ")
            let format = String(localized: "subscription.cycle.calendar_months.format")
            return String(format: format, locale: Locale.autoupdatingCurrent, joined)
        case .oneTime:
            return String(localized: "subscription.cycle.one_time")
        case .customDays:
            let days = subscription.customDaysInterval ?? 1
            let format = String(localized: "subscription.cycle.custom_days.format")
            return String(format: format, locale: Locale.autoupdatingCurrent, days)
        }
    }

    private var filteredEvents: [BillingEvent] {
        subscription.events
            .filter { historyFilter.matches(type: $0.eventType) }
            .sorted { lhs, rhs in
                if lhs.billedAt == rhs.billedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.billedAt > rhs.billedAt
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

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private func eventRow(_ event: BillingEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.billedAt.shortJP())
                    .font(.body.weight(.semibold))

                HStack(spacing: 6) {
                    StatusBadge(
                        text: event.eventType.label,
                        color: event.eventType == .confirmed ? .green : .blue
                    )
                    if event.isAmountOverridden {
                        StatusBadge(text: String(localized: "subscription.detail.event.overridden"), color: .orange)
                    }
                }

                if !event.memo.isEmpty {
                    Text(event.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(event.amount.currencyString(currencyCode: event.currency))
                    .font(.headline)
                if let converted = convertedYen(amount: event.amount, currency: event.currency),
                   event.currency.uppercased() != "JPY" {
                    Text(String(
                        format: String(localized: "common.approx_amount_format"),
                        locale: Locale.autoupdatingCurrent,
                        converted.yenString()
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func convertedYen(amount: Int, currency: String) -> Int? {
        exchangeRates.convertToJPY(amount: amount, currency: currency)
    }

    private var confirmedTotalSummary: String? {
        let confirmedEvents = subscription.events.filter { $0.eventType == .confirmed }
        guard !confirmedEvents.isEmpty else {
            return nil
        }

        var totalJPY = 0
        var unconverted = 0
        for event in confirmedEvents {
            if let converted = convertedYen(amount: event.amount, currency: event.currency) {
                totalJPY += converted
            } else {
                unconverted += 1
            }
        }

        if unconverted > 0 {
            let format = String(localized: "subscription.detail.confirmed_total.with_unconverted_format")
            return String(format: format, locale: Locale.autoupdatingCurrent, totalJPY.yenString(), unconverted)
        }
        return totalJPY.yenString()
    }

    private func formatYearMonth(_ key: String) -> String {
        let components = key.split(separator: "-", omittingEmptySubsequences: true)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              (1 ... 12).contains(month) else {
            return key
        }
        let format = String(localized: "common.year_month_format")
        return String(format: format, locale: Locale.autoupdatingCurrent, year, month)
    }

    private func confirmEvent(_ event: BillingEvent) {
        event.eventType = .confirmed
        event.updatedAt = Date()

        do {
            try modelContext.save()
            AppLogger.subscription.info("event.confirm success")
        } catch {
            errorMessage = String(localized: "subscription.detail.error.confirm_failed")
            AppLogger.error.error("event.confirm failed")
        }
    }

    private func deleteSubscription() {
        modelContext.delete(subscription)
        do {
            try modelContext.save()
            AppLogger.subscription.info("subscription.delete success")
            dismiss()
        } catch {
            errorMessage = String(localized: "subscription.detail.error.delete_failed")
            AppLogger.error.error("subscription.delete failed")
        }
    }

    private func regenerateProjectedEvents() {
        let projectionService = BillingProjectionService()
        projectionService.regenerate(
            for: subscription,
            in: modelContext,
            settings: settings.snapshot
        )

        do {
            try modelContext.save()
        } catch {
            errorMessage = String(localized: "subscription.detail.error.regenerate_failed")
            AppLogger.error.error("projection.regenerate_detail failed")
        }
    }
}
