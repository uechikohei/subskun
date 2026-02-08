import Foundation

enum SubscriptionStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case paused
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active:
            return String(localized: "status.active")
        case .paused:
            return String(localized: "status.paused")
        case .cancelled:
            return String(localized: "status.cancelled")
        }
    }
}

enum SubscriptionStatusFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case paused
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return String(localized: "common.all")
        case .active:
            return String(localized: "status.active")
        case .paused:
            return String(localized: "status.paused")
        case .cancelled:
            return String(localized: "status.cancelled")
        }
    }

    func matches(status: SubscriptionStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .active:
            return status == .active
        case .paused:
            return status == .paused
        case .cancelled:
            return status == .cancelled
        }
    }
}

enum BillingCycleType: String, Codable, CaseIterable, Identifiable {
    case monthly
    case yearly
    case selectedMonths
    case calendarMonths
    case oneTime
    case customDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly:
            return String(localized: "billing_cycle.monthly")
        case .yearly:
            return String(localized: "billing_cycle.yearly")
        case .selectedMonths:
            return String(localized: "billing_cycle.selected_months")
        case .calendarMonths:
            return String(localized: "billing_cycle.calendar_months")
        case .oneTime:
            return String(localized: "billing_cycle.one_time")
        case .customDays:
            return String(localized: "billing_cycle.custom_days")
        }
    }
}

enum BillingEventType: String, Codable, CaseIterable, Identifiable {
    case projected
    case confirmed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .projected:
            return String(localized: "event_type.projected")
        case .confirmed:
            return String(localized: "event_type.confirmed")
        }
    }
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case projected
    case confirmed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return String(localized: "common.all")
        case .projected:
            return String(localized: "event_type.projected")
        case .confirmed:
            return String(localized: "event_type.confirmed")
        }
    }

    func matches(type: BillingEventType) -> Bool {
        switch self {
        case .all:
            return true
        case .projected:
            return type == .projected
        case .confirmed:
            return type == .confirmed
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }

    var label: String {
        rawValue.uppercased()
    }
}

enum ExportScope: String, CaseIterable, Identifiable {
    case definitionsOnly
    case historyOnly
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .definitionsOnly:
            return String(localized: "export.scope.definitions")
        case .historyOnly:
            return String(localized: "export.scope.history")
        case .both:
            return String(localized: "export.scope.both")
        }
    }
}
