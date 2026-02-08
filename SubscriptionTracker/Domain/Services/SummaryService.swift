import Foundation

struct PlanSpendSummary: Identifiable {
    let category: String
    let serviceKey: String
    let planName: String
    let total: Int

    var id: String {
        "\(category)|\(serviceKey)|\(planName)"
    }
}

struct ServiceSpendSummary: Identifiable {
    let category: String
    let serviceKey: String
    let serviceName: String
    let total: Int
    let plans: [PlanSpendSummary]

    var id: String {
        "\(category)|\(serviceKey)"
    }
}

struct CategorySpendSummary: Identifiable {
    let category: String
    let total: Int
    let services: [ServiceSpendSummary]

    var id: String {
        category
    }
}

struct SummaryMetrics {
    let monthProjectedTotal: Int
    let monthConfirmedTotal: Int
    let yearProjectedTotal: Int
    let monthProjectedByCategory: [(category: String, total: Int)]
    let monthProjectedHierarchy: [CategorySpendSummary]
    let unconvertedEventCount: Int
    let upcomingEvents: [BillingEvent]
}

struct SummaryService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func buildSummary(
        from events: [BillingEvent],
        now: Date = Date(),
        includePaused: Bool,
        convertToJPY: (Int, String) -> Int?
    ) -> SummaryMetrics {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now),
              let yearInterval = calendar.dateInterval(of: .year, for: now) else {
            return SummaryMetrics(
                monthProjectedTotal: 0,
                monthConfirmedTotal: 0,
                yearProjectedTotal: 0,
                monthProjectedByCategory: [],
                monthProjectedHierarchy: [],
                unconvertedEventCount: 0,
                upcomingEvents: []
            )
        }

        let startOfToday = calendar.startOfDay(for: now)

        var monthProjected = 0
        var monthConfirmed = 0
        var yearProjected = 0
        var categoryTotals: [String: Int] = [:]
        var hierarchyTotals: [String: [String: [String: Int]]] = [:]
        var serviceDisplayNames: [String: [String: String]] = [:]
        var unconvertedCount = 0

        for event in events {
            guard let subscription = event.subscription else { continue }
            if subscription.status == .paused && !includePaused {
                continue
            }

            guard let amountJPY = convertToJPY(event.amount, event.currency) else {
                unconvertedCount += 1
                continue
            }

            let billedDay = calendar.startOfDay(for: event.billedAt)
            if monthInterval.contains(billedDay) {
                if event.eventType == .projected {
                    monthProjected += amountJPY
                    let key = subscription.category.isEmpty ? String(localized: "common.uncategorized") : subscription.category
                    categoryTotals[key, default: 0] += amountJPY

                    let serviceKey = summaryServiceKey(for: subscription)
                    let serviceName = summaryServiceName(for: subscription)
                    let plan = summaryPlanName(for: subscription)

                    var serviceMap = hierarchyTotals[key, default: [:]]
                    var planMap = serviceMap[serviceKey, default: [:]]
                    planMap[plan, default: 0] += amountJPY
                    serviceMap[serviceKey] = planMap
                    hierarchyTotals[key] = serviceMap

                    var serviceNameMap = serviceDisplayNames[key, default: [:]]
                    serviceNameMap[serviceKey] = serviceName
                    serviceDisplayNames[key] = serviceNameMap
                } else {
                    monthConfirmed += amountJPY
                }
            }

            if yearInterval.contains(billedDay), event.eventType == .projected {
                yearProjected += amountJPY
            }
        }

        let upcoming = events
            .filter { event in
                guard let subscription = event.subscription else { return false }
                if subscription.status == .paused && !includePaused {
                    return false
                }
                return calendar.startOfDay(for: event.billedAt) >= startOfToday
            }
            .sorted { $0.billedAt < $1.billedAt }
            .prefix(5)

        let categorySummary = categoryTotals
            .map { (category: $0.key, total: $0.value) }
            .sorted { lhs, rhs in
                if lhs.total == rhs.total {
                    return lhs.category < rhs.category
                }
                return lhs.total > rhs.total
            }

        let hierarchySummary = buildHierarchySummary(
            totals: hierarchyTotals,
            serviceNames: serviceDisplayNames
        )

        return SummaryMetrics(
            monthProjectedTotal: monthProjected,
            monthConfirmedTotal: monthConfirmed,
            yearProjectedTotal: yearProjected,
            monthProjectedByCategory: categorySummary,
            monthProjectedHierarchy: hierarchySummary,
            unconvertedEventCount: unconvertedCount,
            upcomingEvents: Array(upcoming)
        )
    }

    private func summaryServiceKey(for subscription: Subscription) -> String {
        let catalogID = subscription.serviceCatalogID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !catalogID.isEmpty {
            return "catalog:\(catalogID)"
        }
        return "name:\(normalizedKey(subscription.name))"
    }

    private func summaryServiceName(for subscription: Subscription) -> String {
        let trimmed = subscription.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "common.unnamed_service") : trimmed
    }

    private func summaryPlanName(for subscription: Subscription) -> String {
        let trimmed = subscription.planName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "summary.plan.unspecified") : trimmed
    }

    private func normalizedKey(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    private func buildHierarchySummary(
        totals: [String: [String: [String: Int]]],
        serviceNames: [String: [String: String]]
    ) -> [CategorySpendSummary] {
        totals.map { category, serviceMap in
            let services = serviceMap.map { serviceKey, planMap in
                let plans = planMap
                    .map { planName, total in
                        PlanSpendSummary(
                            category: category,
                            serviceKey: serviceKey,
                            planName: planName,
                            total: total
                        )
                    }
                    .sorted { lhs, rhs in
                        if lhs.total == rhs.total {
                            return lhs.planName < rhs.planName
                        }
                        return lhs.total > rhs.total
                    }

                let serviceTotal = plans.reduce(0) { $0 + $1.total }
                let serviceName = serviceNames[category]?[serviceKey] ?? String(localized: "summary.service.unknown")

                return ServiceSpendSummary(
                    category: category,
                    serviceKey: serviceKey,
                    serviceName: serviceName,
                    total: serviceTotal,
                    plans: plans
                )
            }
            .sorted { lhs, rhs in
                if lhs.total == rhs.total {
                    return lhs.serviceName < rhs.serviceName
                }
                return lhs.total > rhs.total
            }

            let categoryTotal = services.reduce(0) { $0 + $1.total }
            return CategorySpendSummary(
                category: category,
                total: categoryTotal,
                services: services
            )
        }
        .sorted { lhs, rhs in
            if lhs.total == rhs.total {
                return lhs.category < rhs.category
            }
            return lhs.total > rhs.total
        }
    }
}
