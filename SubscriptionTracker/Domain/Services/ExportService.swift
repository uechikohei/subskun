import Foundation

struct ExportService {
    private let csvWriter = CSVWriter()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func writeExport(
        format: ExportFormat,
        scope: ExportScope,
        subscriptions: [Subscription],
        events: [BillingEvent],
        settings: SettingsSnapshot,
        now: Date = Date()
    ) throws -> URL {
        let startedAt = Date()
        let data: Data
        let fileName: String

        switch format {
        case .json:
            data = try makeJSONData(
                scope: scope,
                subscriptions: subscriptions,
                events: events,
                settings: settings,
                now: now
            )
            fileName = "subscriptions_export_\(timestamp(now)).json"
        case .csv:
            data = try makeCSVData(
                scope: scope,
                subscriptions: subscriptions,
                events: events
            )
            fileName = "subscriptions_export_\(timestamp(now)).csv"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)

        let duration = Int(Date().timeIntervalSince(startedAt) * 1000)
        AppLogger.export.info("export.success format=\(format.rawValue, privacy: .public) scope=\(scope.rawValue, privacy: .public) duration_ms=\(duration, privacy: .public)")

        return url
    }

    func makeJSONData(
        scope: ExportScope,
        subscriptions: [Subscription],
        events: [BillingEvent],
        settings: SettingsSnapshot,
        now: Date = Date()
    ) throws -> Data {
        let dayFormatter = makeDayFormatter()
        let dateTimeFormatter = makeDateTimeFormatter()

        let mappedSubscriptions: [ExportSubscriptionDTO]
        switch scope {
        case .historyOnly:
            mappedSubscriptions = []
        case .definitionsOnly, .both:
            mappedSubscriptions = subscriptions
                .sorted { $0.createdAt < $1.createdAt }
                .map { subscription in
                    ExportSubscriptionDTO(
                        id: subscription.id.uuidString,
                        name: subscription.name,
                        serviceCatalogID: subscription.serviceCatalogID.isEmpty ? nil : subscription.serviceCatalogID,
                        planName: subscription.planName.isEmpty ? nil : subscription.planName,
                        status: subscription.status.rawValue,
                        category: subscription.category,
                        amount: subscription.amount,
                        currency: subscription.currency,
                        firstBillingDate: dayFormatter.string(from: subscription.firstBillingDate),
                        cancellationDate: subscription.cancellationDate.map { dayFormatter.string(from: $0) },
                        billingCycle: ExportBillingCycleDTO(
                            type: subscription.billingCycleType.rawValue,
                            interval: subscription.billingInterval,
                            customDaysInterval: subscription.customDaysInterval,
                            selectedMonths: subscription.selectedMonths.isEmpty ? nil : subscription.selectedMonths,
                            selectedYearMonths: subscription.selectedYearMonths.isEmpty ? nil : subscription.selectedYearMonths,
                            historicalBilledYearMonths: subscription.historicalBilledYearMonths.isEmpty ? nil : subscription.historicalBilledYearMonths
                        ),
                        memo: subscription.memo,
                        createdAt: dateTimeFormatter.string(from: subscription.createdAt),
                        updatedAt: dateTimeFormatter.string(from: subscription.updatedAt)
                    )
                }
        }

        let mappedEvents: [ExportBillingEventDTO]
        switch scope {
        case .definitionsOnly:
            mappedEvents = []
        case .historyOnly, .both:
            mappedEvents = events
                .sorted { $0.billedAt < $1.billedAt }
                .compactMap { event in
                    guard let subscription = event.subscription else { return nil }
                    return ExportBillingEventDTO(
                        id: event.id.uuidString,
                        subscriptionId: subscription.id.uuidString,
                        billedAt: dayFormatter.string(from: event.billedAt),
                        amount: event.amount,
                        currency: event.currency,
                        eventType: event.eventType.rawValue,
                        isAmountOverridden: event.isAmountOverridden,
                        memo: event.memo,
                        createdAt: dateTimeFormatter.string(from: event.createdAt),
                        updatedAt: dateTimeFormatter.string(from: event.updatedAt)
                    )
                }
        }

        let dto = ExportEnvelopeDTO(
            schemaVersion: "1.0",
            exportedAt: dateTimeFormatter.string(from: now),
            settings: ExportSettingsDTO(
                timezone: calendar.timeZone.identifier,
                historyRange: ExportHistoryRangeDTO(
                    pastMonths: settings.pastMonths,
                    futureMonths: settings.futureMonths
                )
            ),
            subscriptions: mappedSubscriptions,
            billingEvents: mappedEvents
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(dto)
    }

    func makeCSVData(
        scope: ExportScope,
        subscriptions: [Subscription],
        events: [BillingEvent]
    ) throws -> Data {
        let dayFormatter = makeDayFormatter()
        let dateTimeFormatter = makeDateTimeFormatter()

        let text: String

        if scope == .definitionsOnly {
            let headers = [
                "subscription_id",
                "name",
                "service_catalog_id",
                "plan_name",
                "status",
                "category",
                "amount",
                "currency",
                "first_billing_date",
                "cancellation_date",
                "billing_cycle_type",
                "billing_interval",
                "custom_days_interval",
                "selected_months",
                "selected_year_months",
                "historical_billed_year_months",
                "memo",
                "created_at",
                "updated_at"
            ]

            let rows = subscriptions
                .sorted { $0.createdAt < $1.createdAt }
                .map { subscription in
                    [
                        subscription.id.uuidString,
                        subscription.name,
                        subscription.serviceCatalogID,
                        subscription.planName,
                        subscription.status.rawValue,
                        subscription.category,
                        String(subscription.amount),
                        subscription.currency,
                        dayFormatter.string(from: subscription.firstBillingDate),
                        subscription.cancellationDate.map { dayFormatter.string(from: $0) } ?? "",
                        subscription.billingCycleType.rawValue,
                        String(subscription.billingInterval),
                        subscription.customDaysInterval.map(String.init) ?? "",
                        subscription.selectedMonths.map(String.init).joined(separator: "|"),
                        subscription.selectedYearMonths.joined(separator: "|"),
                        subscription.historicalBilledYearMonths.joined(separator: "|"),
                        subscription.memo,
                        dateTimeFormatter.string(from: subscription.createdAt),
                        dateTimeFormatter.string(from: subscription.updatedAt)
                    ]
                }

            text = csvWriter.makeCSV(headers: headers, rows: rows)
        } else {
            let headers = [
                "event_id",
                "subscription_id",
                "subscription_name",
                "subscription_status",
                "category",
                "billed_at",
                "amount",
                "currency",
                "event_type",
                "is_amount_overridden",
                "memo"
            ]

            let rows = events
                .sorted { $0.billedAt < $1.billedAt }
                .compactMap { event -> [String]? in
                    guard let subscription = event.subscription else { return nil }
                    return [
                        event.id.uuidString,
                        subscription.id.uuidString,
                        subscription.name,
                        subscription.status.rawValue,
                        subscription.category,
                        dayFormatter.string(from: event.billedAt),
                        String(event.amount),
                        event.currency,
                        event.eventType.rawValue,
                        String(event.isAmountOverridden),
                        event.memo
                    ]
                }

            text = csvWriter.makeCSV(headers: headers, rows: rows)
        }

        guard let data = text.data(using: .utf8) else {
            throw ExportError.csvEncodingFailed
        }

        return data
    }

    private func makeDayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func makeDateTimeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }

    private func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

enum ExportError: Error, LocalizedError {
    case csvEncodingFailed

    var errorDescription: String? {
        switch self {
        case .csvEncodingFailed:
            return String(localized: "export.error.csv_encoding_failed")
        }
    }
}
