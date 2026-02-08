import Charts
import Foundation
import SwiftData
import SwiftUI

private func localizedYearLabel(_ year: Int) -> String {
    String(
        format: String(localized: "common.year_number_format"),
        locale: Locale.autoupdatingCurrent,
        year
    )
}

private func localizedMonthLabel(_ month: Int) -> String {
    String(
        format: String(localized: "common.month_number_short"),
        locale: Locale.autoupdatingCurrent,
        month
    )
}

struct SummaryView: View {
    @EnvironmentObject private var exchangeRates: ExchangeRateStore

    @Query(sort: [SortDescriptor(\BillingEvent.billedAt, order: .forward)])
    private var events: [BillingEvent]

    @State private var period: AnalysisPeriod = .monthly
    @State private var grouping: AnalysisGrouping = .service
    @State private var scope: AnalysisScope = .projected
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    private let palette: [Color] = [
        Color(red: 0.11, green: 0.73, blue: 0.88),
        Color(red: 0.95, green: 0.50, blue: 0.48),
        Color(red: 0.92, green: 0.82, blue: 0.29),
        Color(red: 0.73, green: 0.87, blue: 0.35),
        Color(red: 0.53, green: 0.80, blue: 0.77),
        Color(red: 0.95, green: 0.73, blue: 0.57),
        Color(red: 0.69, green: 0.71, blue: 0.98),
        Color(red: 0.83, green: 0.62, blue: 0.94)
    ]

    var body: some View {
        let breakdown = currentBreakdown

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker(String(localized: "summary.picker.period"), selection: $period) {
                    ForEach(AnalysisPeriod.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    yearPicker
                    Spacer()
                    Picker(String(localized: "summary.picker.scope"), selection: $scope) {
                        ForEach(AnalysisScope.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if period == .monthly {
                    monthSelector
                }

                HStack(spacing: 12) {
                    Picker(String(localized: "summary.picker.grouping"), selection: $grouping) {
                        ForEach(AnalysisGrouping.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if breakdown.slices.isEmpty {
                    ContentUnavailableView(
                        String(localized: "summary.empty.title"),
                        systemImage: "chart.pie",
                        description: Text(String(localized: "summary.empty.description"))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    Chart(breakdown.slices) { slice in
                        SectorMark(
                            angle: .value(String(localized: "common.amount"), slice.total),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color)
                    }
                    .frame(height: 340)
                    .chartLegend(.hidden)
                    .overlay {
                        VStack(spacing: 4) {
                            Text(String(localized: "summary.grouping.total"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(breakdown.total.yenString())
                                .font(.title.bold())
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(breakdown.slices) { slice in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(slice.color)
                                    .frame(width: 16, height: 16)
                                Text(slice.label)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Text(slice.total.yenString())
                                    .font(.body.weight(.semibold))
                            }
                            .padding(.vertical, 12)

                            if slice.id != breakdown.slices.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if breakdown.unconvertedCount > 0 {
                    Text(String(
                        format: String(localized: "summary.unconverted_count.format"),
                        locale: Locale.autoupdatingCurrent,
                        breakdown.unconvertedCount
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(String(localized: "summary.navigation_title"))
        .task {
            await exchangeRates.refreshIfNeeded()
            syncSelectionWithAvailableYears()
        }
        .onChange(of: period) { _, _ in
            syncSelectionWithAvailableYears()
        }
        .onChange(of: scope) { _, _ in
            syncSelectionWithAvailableYears()
        }
        .onChange(of: events.count) { _, _ in
            syncSelectionWithAvailableYears()
        }
    }

    private var currentBreakdown: BreakdownResult {
        let calendar = Calendar.current
        guard let interval = selectedInterval(calendar: calendar) else {
            return BreakdownResult(slices: [], total: 0, unconvertedCount: 0)
        }

        var totals: [String: Int] = [:]
        var unconvertedCount = 0

        for event in events {
            guard scope.matches(event.eventType) else {
                continue
            }
            let day = calendar.startOfDay(for: event.billedAt)
            guard interval.contains(day) else {
                continue
            }
            guard let amountJPY = convertedToJPY(event) else {
                unconvertedCount += 1
                continue
            }
            let key = grouping.key(for: event.subscription)
            totals[key, default: 0] += amountJPY
        }

        let sorted = totals
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }

        let slices = sorted.enumerated().map { index, item in
            BreakdownSlice(
                label: item.0,
                total: item.1,
                color: palette[index % palette.count]
            )
        }

        let total = slices.reduce(0) { $0 + $1.total }
        return BreakdownResult(
            slices: slices,
            total: total,
            unconvertedCount: unconvertedCount
        )
    }

    @ViewBuilder
    private var yearPicker: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button(localizedYearLabel(year)) {
                    selectedYear = year
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(localizedYearLabel(selectedYear))
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.secondary.opacity(0.14))
            )
        }
    }

    @ViewBuilder
    private var monthSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1 ... 12, id: \.self) { month in
                    Button {
                        selectedMonth = month
                    } label: {
                        Text(localizedMonthLabel(month))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedMonth == month ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedMonth == month ? Color.accentColor : Color.secondary.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var availableYears: [Int] {
        let years = Set(events.map { Calendar.current.component(.year, from: $0.billedAt) })
        if years.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }
        return Array(years).sorted()
    }

    private func selectedInterval(calendar: Calendar) -> DateInterval? {
        switch period {
        case .monthly:
            guard let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) else {
                return nil
            }
            return calendar.dateInterval(of: .month, for: date)
        case .yearly:
            guard let date = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) else {
                return nil
            }
            return calendar.dateInterval(of: .year, for: date)
        }
    }

    private func convertedToJPY(_ event: BillingEvent) -> Int? {
        let code = event.currency.uppercased()
        if code == "JPY" {
            return event.amount
        }
        return exchangeRates.convertToJPY(amount: event.amount, currency: code)
    }

    private func syncSelectionWithAvailableYears() {
        guard let minYear = availableYears.min(), let maxYear = availableYears.max() else {
            return
        }
        if selectedYear < minYear || selectedYear > maxYear {
            selectedYear = maxYear
        }
        if !(1 ... 12).contains(selectedMonth) {
            selectedMonth = 1
        }
    }
}

private struct BreakdownResult {
    let slices: [BreakdownSlice]
    let total: Int
    let unconvertedCount: Int
}

private struct BreakdownSlice: Identifiable {
    let label: String
    let total: Int
    let color: Color

    var id: String { label }
}

private enum AnalysisPeriod: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly:
            return String(localized: "summary.period.monthly")
        case .yearly:
            return String(localized: "summary.period.yearly")
        }
    }

    func interval(for date: Date, calendar: Calendar) -> DateInterval? {
        switch self {
        case .monthly:
            return calendar.dateInterval(of: .month, for: date)
        case .yearly:
            return calendar.dateInterval(of: .year, for: date)
        }
    }
}

private enum AnalysisGrouping: String, CaseIterable, Identifiable {
    case total
    case category
    case service

    var id: String { rawValue }

    var label: String {
        switch self {
        case .total:
            return String(localized: "summary.grouping.total")
        case .category:
            return String(localized: "summary.grouping.category")
        case .service:
            return String(localized: "summary.grouping.service")
        }
    }

    func key(for subscription: Subscription?) -> String {
        switch self {
        case .total:
            return String(localized: "common.all")
        case .category:
            let trimmed = subscription?.category.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? String(localized: "common.uncategorized") : trimmed
        case .service:
            let trimmed = subscription?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? String(localized: "common.unnamed_service") : trimmed
        }
    }
}

private enum AnalysisScope: String, CaseIterable, Identifiable {
    case projected
    case confirmed
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .projected:
            return String(localized: "event_type.projected")
        case .confirmed:
            return String(localized: "event_type.confirmed")
        case .both:
            return String(localized: "common.all")
        }
    }

    func matches(_ type: BillingEventType) -> Bool {
        switch self {
        case .projected:
            return type == .projected
        case .confirmed:
            return type == .confirmed
        case .both:
            return true
        }
    }
}

struct PaymentHistoryView: View {
    @EnvironmentObject private var exchangeRates: ExchangeRateStore

    @Query(sort: [SortDescriptor(\BillingEvent.billedAt, order: .forward)])
    private var events: [BillingEvent]

    @State private var period: HistoryPeriod = .monthly
    @State private var grouping: HistoryGrouping = .total
    @State private var scope: HistoryScope = .confirmed
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    private let colorPalette: [Color] = [
        .blue, .mint, .orange, .pink, .indigo, .teal, .yellow, .purple, .green
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker(String(localized: "history.picker.period"), selection: $period) {
                    ForEach(HistoryPeriod.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    yearPicker
                    Spacer()
                    Picker(String(localized: "history.picker.grouping"), selection: $grouping) {
                        ForEach(HistoryGrouping.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Picker(String(localized: "history.picker.scope"), selection: $scope) {
                        ForEach(HistoryScope.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if displayPoints.isEmpty {
                    ContentUnavailableView(
                        String(localized: "history.empty.title"),
                        systemImage: "chart.bar",
                        description: Text(String(localized: "history.empty.description"))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    Chart(displayPoints) { point in
                        BarMark(
                            x: .value(String(localized: "common.period"), point.label),
                            y: .value(String(localized: "common.amount"), point.total)
                        )
                        .foregroundStyle(color(forGroup: point.group))
                        .cornerRadius(6)
                    }
                    .frame(height: 260)
                    .chartLegend(grouping == .total ? .hidden : .visible)
                }

                if period == .monthly {
                    monthSelector

                    VStack(alignment: .leading, spacing: 6) {
                        Text(localizedMonthLabel(selectedMonth))
                            .font(.headline)
                        Text(selectedMonthTotal.yenString())
                            .font(.title.bold())
                    }

                    if selectedMonthEvents.isEmpty {
                        Text(String(localized: "history.month.empty"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(selectedMonthEvents) { item in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.serviceName)
                                            .font(.body.weight(.semibold))
                                        Text(item.date.shortJP())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.amountJPY.yenString())
                                        .font(.body.weight(.semibold))
                                }
                                .padding(.vertical, 12)

                                if item.id != selectedMonthEvents.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(
                            format: String(localized: "history.year.total_title_format"),
                            locale: Locale.autoupdatingCurrent,
                            localizedYearLabel(selectedYear)
                        ))
                            .font(.headline)
                        Text(selectedYearTotal.yenString())
                            .font(.title.bold())
                    }
                }

                if unconvertedCount > 0 {
                    Text(String(
                        format: String(localized: "history.unconverted_count.format"),
                        locale: Locale.autoupdatingCurrent,
                        unconvertedCount
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(String(localized: "history.navigation_title"))
        .task {
            await exchangeRates.refreshIfNeeded()
            syncSelectionWithAvailableYears()
        }
        .onChange(of: period) { _, _ in
            syncSelectionWithAvailableYears()
        }
        .onChange(of: scope) { _, _ in
            syncSelectionWithAvailableYears()
        }
    }

    @ViewBuilder
    private var yearPicker: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button(localizedYearLabel(year)) {
                    selectedYear = year
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(localizedYearLabel(selectedYear))
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.secondary.opacity(0.14))
            )
        }
    }

    @ViewBuilder
    private var monthSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1 ... 12, id: \.self) { month in
                    Button {
                        selectedMonth = month
                    } label: {
                        Text(localizedMonthLabel(month))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedMonth == month ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedMonth == month ? Color.accentColor : Color.secondary.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var availableYears: [Int] {
        let years = convertedEvents.map { Calendar.current.component(.year, from: $0.date) }
        let set = Set(years)
        if set.isEmpty {
            return [Calendar.current.component(.year, from: Date())]
        }
        return Array(set).sorted()
    }

    private var convertedEvents: [ConvertedHistoryEvent] {
        events.compactMap { event in
            guard scope.matches(event.eventType) else {
                return nil
            }
            guard let amountJPY = convertedToJPY(event) else {
                return nil
            }
            let service = event.subscription?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let category = event.subscription?.category.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return ConvertedHistoryEvent(
                id: event.id,
                date: event.billedAt,
                amountJPY: amountJPY,
                serviceName: service.isEmpty ? String(localized: "common.unnamed_service") : service,
                categoryName: category.isEmpty ? String(localized: "common.uncategorized") : category
            )
        }
    }

    private var unconvertedCount: Int {
        events.reduce(into: 0) { count, event in
            guard scope.matches(event.eventType) else { return }
            if convertedToJPY(event) == nil {
                count += 1
            }
        }
    }

    private var displayPoints: [HistoryPoint] {
        switch period {
        case .monthly:
            return monthlyPoints
        case .yearly:
            return yearlyPoints
        }
    }

    private var monthlyPoints: [HistoryPoint] {
        let yearEvents = convertedEvents.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }
        return buildPoints(
            source: yearEvents,
            bucketValues: Array(1 ... 12),
            bucketForEvent: { Calendar.current.component(.month, from: $0.date) },
            labelForBucket: { localizedMonthLabel($0) }
        )
    }

    private var yearlyPoints: [HistoryPoint] {
        buildPoints(
            source: convertedEvents,
            bucketValues: availableYears,
            bucketForEvent: { Calendar.current.component(.year, from: $0.date) },
            labelForBucket: { localizedYearLabel($0) }
        )
    }

    private var selectedMonthEvents: [ConvertedHistoryEvent] {
        convertedEvents
            .filter {
                Calendar.current.component(.year, from: $0.date) == selectedYear &&
                    Calendar.current.component(.month, from: $0.date) == selectedMonth
            }
            .sorted { lhs, rhs in
                if lhs.amountJPY == rhs.amountJPY {
                    return lhs.date < rhs.date
                }
                return lhs.amountJPY > rhs.amountJPY
            }
    }

    private var selectedMonthTotal: Int {
        selectedMonthEvents.reduce(0) { $0 + $1.amountJPY }
    }

    private var selectedYearTotal: Int {
        convertedEvents
            .filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
            .reduce(0) { $0 + $1.amountJPY }
    }

    private func buildPoints(
        source: [ConvertedHistoryEvent],
        bucketValues: [Int],
        bucketForEvent: (ConvertedHistoryEvent) -> Int,
        labelForBucket: (Int) -> String
    ) -> [HistoryPoint] {
        var globalGroupTotals: [String: Int] = [:]
        for event in source {
            let group = grouping.groupKey(for: event)
            globalGroupTotals[group, default: 0] += event.amountJPY
        }

        let majorGroups: Set<String>
        if grouping == .total {
            majorGroups = [String(localized: "summary.grouping.total")]
        } else {
            majorGroups = Set(
                globalGroupTotals
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            return lhs.key < rhs.key
                        }
                        return lhs.value > rhs.value
                    }
                    .prefix(6)
                    .map(\.key)
            )
        }

        var bucketMap: [Int: [String: Int]] = [:]
        for bucket in bucketValues {
            bucketMap[bucket] = [:]
        }

        for event in source {
            let bucket = bucketForEvent(event)
            guard bucketMap[bucket] != nil else { continue }
            let rawGroup = grouping.groupKey(for: event)
            let group = grouping == .total || majorGroups.contains(rawGroup) ? rawGroup : String(localized: "common.others")
            bucketMap[bucket, default: [:]][group, default: 0] += event.amountJPY
        }

        var points: [HistoryPoint] = []

        for bucket in bucketValues {
            let groups = bucketMap[bucket, default: [:]]
            if grouping == .total {
                let totalLabel = String(localized: "summary.grouping.total")
                let value = groups[totalLabel, default: 0]
                points.append(
                    HistoryPoint(
                        bucket: bucket,
                        label: labelForBucket(bucket),
                        group: totalLabel,
                        total: value
                    )
                )
            } else {
                let sortedGroups = groups.sorted { lhs, rhs in
                    if lhs.value == rhs.value {
                        return lhs.key < rhs.key
                    }
                    return lhs.value > rhs.value
                }

                for item in sortedGroups {
                    points.append(
                        HistoryPoint(
                            bucket: bucket,
                            label: labelForBucket(bucket),
                            group: item.key,
                            total: item.value
                        )
                    )
                }
            }
        }

        return points
    }

    private func color(forGroup group: String) -> Color {
        if group == String(localized: "summary.grouping.total") {
            return .blue
        }
        let hash = abs(group.hashValue)
        return colorPalette[hash % colorPalette.count]
    }

    private func convertedToJPY(_ event: BillingEvent) -> Int? {
        let currency = event.currency.uppercased()
        if currency == "JPY" {
            return event.amount
        }
        return exchangeRates.convertToJPY(amount: event.amount, currency: currency)
    }

    private func syncSelectionWithAvailableYears() {
        guard let minYear = availableYears.min(),
              let maxYear = availableYears.max() else {
            return
        }
        if selectedYear < minYear || selectedYear > maxYear {
            selectedYear = maxYear
        }
        if !(1 ... 12).contains(selectedMonth) {
            selectedMonth = 1
        }
    }
}

private struct ConvertedHistoryEvent: Identifiable {
    let id: UUID
    let date: Date
    let amountJPY: Int
    let serviceName: String
    let categoryName: String
}

private struct HistoryPoint: Identifiable {
    let bucket: Int
    let label: String
    let group: String
    let total: Int

    var id: String {
        "\(bucket)-\(group)"
    }
}

private enum HistoryPeriod: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthly:
            return String(localized: "summary.period.monthly")
        case .yearly:
            return String(localized: "summary.period.yearly")
        }
    }
}

private enum HistoryGrouping: String, CaseIterable, Identifiable {
    case total
    case category
    case service

    var id: String { rawValue }

    var label: String {
        switch self {
        case .total:
            return String(localized: "summary.grouping.total")
        case .category:
            return String(localized: "history.grouping.category")
        case .service:
            return String(localized: "history.grouping.service")
        }
    }

    func groupKey(for event: ConvertedHistoryEvent) -> String {
        switch self {
        case .total:
            return String(localized: "summary.grouping.total")
        case .category:
            return event.categoryName
        case .service:
            return event.serviceName
        }
    }
}

private enum HistoryScope: String, CaseIterable, Identifiable {
    case confirmed
    case projected
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .confirmed:
            return String(localized: "event_type.confirmed")
        case .projected:
            return String(localized: "event_type.projected")
        case .both:
            return String(localized: "common.all")
        }
    }

    func matches(_ type: BillingEventType) -> Bool {
        switch self {
        case .confirmed:
            return type == .confirmed
        case .projected:
            return type == .projected
        case .both:
            return true
        }
    }
}
