import Foundation

public struct CalendarGridMove: Equatable, Sendable {
    public let date: Date
    public let displayedMonth: Date

    public init(date: Date, displayedMonth: Date) {
        self.date = date
        self.displayedMonth = displayedMonth
    }
}

public enum CalendarGridNavigator {
    public static func monthStart(
        containing date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.dateInterval(of: .month, for: date)?.start
    }

    public static func horizontalMove(
        from date: Date,
        displayedMonth: Date,
        direction: Int,
        calendar: Calendar = .current
    ) -> CalendarGridMove? {
        guard direction == -1 || direction == 1,
              let month = monthStart(containing: displayedMonth, calendar: calendar),
              let days = calendar.range(of: .day, in: .month, for: month),
              let offset = calendar.dateComponents([.day], from: month, to: date).day
        else { return nil }

        let leading = leadingDayCount(for: month, calendar: calendar)
        let index = leading + offset
        guard (0..<42).contains(index) else { return nil }
        let row = index / 7
        let column = index % 7
        let day = calendar.component(.day, from: date)
        let isMonthBoundary = direction == -1
            ? day == days.lowerBound
            : day == days.upperBound - 1
        let isColumnBoundary = direction == -1 ? column == 0 : column == 6

        if !isColumnBoundary {
            guard let moved = calendar.date(byAdding: .day, value: direction, to: date) else {
                return nil
            }
            let targetMonth = isMonthBoundary
                ? monthStart(containing: moved, calendar: calendar) ?? month
                : month
            return CalendarGridMove(date: moved, displayedMonth: targetMonth)
        }

        guard let targetMonth = calendar.date(
            byAdding: .month,
            value: direction,
            to: month
        ) else { return nil }
        let targetLeading = leadingDayCount(for: targetMonth, calendar: calendar)
        let targetDays = calendar.range(of: .day, in: .month, for: targetMonth)
        let first = row * 7
        let last = first + 6
        let validFirst = max(first, targetLeading)
        let validLast = min(last, targetLeading + (targetDays?.count ?? 0) - 1)
        let targetIndex = direction == -1 ? validLast : validFirst
        let targetOffset = targetIndex - targetLeading
        guard let moved = calendar.date(
            byAdding: .day,
            value: targetOffset,
            to: targetMonth
        ) else { return nil }
        return CalendarGridMove(date: moved, displayedMonth: targetMonth)
    }

    public static func gridDates(
        displayedMonth: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let month = monthStart(containing: displayedMonth, calendar: calendar) else {
            return []
        }
        let leading = leadingDayCount(for: month, calendar: calendar)
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0 - leading, to: month)
        }
    }

    public static func shiftedSelection(
        date: Date,
        displayedMonth: Date,
        component: Calendar.Component,
        value: Int,
        calendar: Calendar = .current
    ) -> CalendarGridMove? {
        guard component == .month || component == .year,
              let month = monthStart(containing: displayedMonth, calendar: calendar),
              let targetMonth = calendar.date(byAdding: component, value: value, to: month),
              let days = calendar.range(of: .day, in: .month, for: targetMonth)
        else { return nil }
        var parts = calendar.dateComponents([.year, .month], from: targetMonth)
        parts.day = min(calendar.component(.day, from: date), days.upperBound - 1)
        guard let targetDate = calendar.date(from: parts) else { return nil }
        return CalendarGridMove(date: targetDate, displayedMonth: targetMonth)
    }

    private static func leadingDayCount(for month: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: month)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}
