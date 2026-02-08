import Foundation

struct BillingEngine {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func generateProjectedDates(
        for subscription: Subscription,
        rangeStart: Date,
        rangeEnd: Date,
        confirmedDates: Set<Date>
    ) -> [Date] {
        if subscription.status == .paused {
            return []
        }

        let start = calendar.startOfDay(for: rangeStart)
        var end = calendar.startOfDay(for: rangeEnd)

        if subscription.status == .cancelled, let cancellationDate = subscription.cancellationDate {
            end = min(end, calendar.startOfDay(for: cancellationDate))
        }

        guard start <= end else { return [] }

        var output: [Date] = []
        var index = 0
        var safety = 0

        guard var occurrence = occurrenceDate(for: subscription, index: index) else {
            return []
        }

        while occurrence < start && safety < 20_000 {
            index += 1
            safety += 1
            guard let next = occurrenceDate(for: subscription, index: index) else { break }
            occurrence = next
        }

        while occurrence <= end && safety < 40_000 {
            let normalized = calendar.startOfDay(for: occurrence)
            if !confirmedDates.contains(normalized) {
                output.append(normalized)
            }
            index += 1
            safety += 1
            guard let next = occurrenceDate(for: subscription, index: index) else { break }
            occurrence = next
        }

        return output
    }

    func nextBillingDate(for subscription: Subscription, from referenceDate: Date = Date()) -> Date? {
        if subscription.status == .paused {
            return nil
        }

        let start = calendar.startOfDay(for: referenceDate)

        if subscription.status == .cancelled,
           let cancellationDate = subscription.cancellationDate,
           calendar.startOfDay(for: cancellationDate) < start {
            return nil
        }

        var index = 0
        var safety = 0

        guard var occurrence = occurrenceDate(for: subscription, index: index) else {
            return nil
        }

        while occurrence < start && safety < 20_000 {
            index += 1
            safety += 1
            guard let next = occurrenceDate(for: subscription, index: index) else { return nil }
            occurrence = next
        }

        if subscription.status == .cancelled,
           let cancellationDate = subscription.cancellationDate,
           occurrence > calendar.startOfDay(for: cancellationDate) {
            return nil
        }

        return occurrence
    }

    private func occurrenceDate(for subscription: Subscription, index: Int) -> Date? {
        let anchor = calendar.startOfDay(for: subscription.firstBillingDate)

        switch subscription.billingCycleType {
        case .monthly:
            return monthlyOccurrence(anchor: anchor, interval: max(1, subscription.billingInterval), index: index)
        case .yearly:
            return yearlyOccurrence(anchor: anchor, interval: max(1, subscription.billingInterval), index: index)
        case .selectedMonths:
            return selectedMonthsOccurrence(anchor: anchor, months: subscription.selectedMonths, index: index)
        case .calendarMonths:
            return calendarMonthsOccurrence(anchor: anchor, yearMonths: subscription.selectedYearMonths, index: index)
        case .oneTime:
            return index == 0 ? anchor : nil
        case .customDays:
            let days = max(1, subscription.customDaysInterval ?? 1)
            return calendar.date(byAdding: .day, value: days * index, to: anchor)
        }
    }

    private func selectedMonthsOccurrence(anchor: Date, months: [Int], index: Int) -> Date? {
        let filtered = Array(Set(months.filter { (1 ... 12).contains($0) })).sorted()
        guard !filtered.isEmpty, index >= 0 else {
            return nil
        }

        let anchorComponents = calendar.dateComponents([.year, .month, .day], from: anchor)
        guard let anchorYear = anchorComponents.year,
              let anchorMonth = anchorComponents.month,
              let anchorDay = anchorComponents.day else {
            return nil
        }

        var year = anchorYear
        var month = anchorMonth
        var hitCount = 0
        var safety = 0

        while safety < 20_000 {
            if filtered.contains(month),
               let candidate = clampedDate(year: year, month: month, day: anchorDay),
               candidate >= anchor {
                if hitCount == index {
                    return candidate
                }
                hitCount += 1
            }

            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
            safety += 1
        }

        return nil
    }

    private func calendarMonthsOccurrence(anchor: Date, yearMonths: [String], index: Int) -> Date? {
        guard index >= 0 else { return nil }

        let anchorDay = calendar.component(.day, from: anchor)
        var seen: Set<String> = []
        let candidates = yearMonths
            .compactMap(Self.parseYearMonthKey)
            .map { Self.yearMonthKey(year: $0.year, month: $0.month) }
            .filter { seen.insert($0).inserted }
            .sorted(by: Self.yearMonthLessThan)
            .compactMap { key -> Date? in
                guard let components = Self.parseYearMonthKey(key) else { return nil }
                return clampedDate(year: components.year, month: components.month, day: anchorDay)
            }
            .filter { $0 >= anchor }

        guard index < candidates.count else { return nil }
        return candidates[index]
    }

    private func monthlyOccurrence(anchor: Date, interval: Int, index: Int) -> Date? {
        let anchorComponents = calendar.dateComponents([.year, .month, .day], from: anchor)
        guard let anchorYear = anchorComponents.year,
              let anchorMonth = anchorComponents.month,
              let anchorDay = anchorComponents.day,
              let anchorMonthStart = calendar.date(from: DateComponents(year: anchorYear, month: anchorMonth, day: 1)) else {
            return nil
        }

        let monthOffset = interval * index
        guard let targetMonthStart = calendar.date(byAdding: .month, value: monthOffset, to: anchorMonthStart) else {
            return nil
        }

        let targetComponents = calendar.dateComponents([.year, .month], from: targetMonthStart)
        guard let year = targetComponents.year,
              let month = targetComponents.month,
              let range = calendar.range(of: .day, in: .month, for: targetMonthStart) else {
            return nil
        }

        let day = min(anchorDay, range.count)
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func yearlyOccurrence(anchor: Date, interval: Int, index: Int) -> Date? {
        let anchorComponents = calendar.dateComponents([.year, .month, .day], from: anchor)
        guard let anchorYear = anchorComponents.year,
              let month = anchorComponents.month,
              let anchorDay = anchorComponents.day else {
            return nil
        }

        let year = anchorYear + interval * index
        guard let targetMonthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: targetMonthStart) else {
            return nil
        }

        let day = min(anchorDay, range.count)
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func clampedDate(year: Int, month: Int, day: Int) -> Date? {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }
        let clampedDay = min(day, range.count)
        return calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
    }

    private static func parseYearMonthKey(_ raw: String) -> (year: Int, month: Int)? {
        let components = raw.split(separator: "-", omittingEmptySubsequences: true)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              (1 ... 12).contains(month),
              (1900 ... 3000).contains(year) else {
            return nil
        }
        return (year, month)
    }

    private static func yearMonthKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    private static func yearMonthLessThan(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = parseYearMonthKey(lhs), let right = parseYearMonthKey(rhs) else {
            return lhs < rhs
        }
        if left.year != right.year {
            return left.year < right.year
        }
        return left.month < right.month
    }
}
