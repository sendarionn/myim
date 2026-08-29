import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CalendarGridNavigatorTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 1
        return value
    }

    @Test func rightEdgeMovesToOppositeEdgeInNextMonth() throws {
        #expect(try moved((2026, 7, 4), month: (2026, 7, 1), direction: 1) == [2026, 8, 1])
        #expect(try moved((2026, 8, 1), month: (2026, 8, 1), direction: 1) == [2026, 9, 1])
        #expect(try moved((2026, 7, 25), month: (2026, 7, 1), direction: 1) == [2026, 8, 16])
        #expect(try moved((2026, 8, 29), month: (2026, 8, 1), direction: 1) == [2026, 9, 27])
    }

    @Test func monthBoundaryMovesToAdjacentCalendarDay() throws {
        #expect(try moved((2026, 9, 30), month: (2026, 9, 1), direction: 1) == [2026, 10, 1])
        #expect(try moved((2026, 8, 1), month: (2026, 8, 1), direction: -1) == [2026, 7, 31])
    }

    @Test func calendarColumnEdgeTakesPriorityOverMonthBoundary() throws {
        #expect(try moved((2026, 11, 1), month: (2026, 11, 1), direction: -1) == [2026, 10, 3])
    }

    @Test func interiorMovementUsesAdjacentDate() throws {
        #expect(try moved((2026, 9, 3), month: (2026, 9, 1), direction: 1) == [2026, 9, 4])
        #expect(try moved((2026, 9, 3), month: (2026, 9, 1), direction: -1) == [2026, 9, 2])
    }

    @Test func createsSixBySevenGrid() throws {
        let dates = CalendarGridNavigator.gridDates(
            displayedMonth: try date(2026, 9, 1),
            calendar: calendar
        )
        #expect(dates.count == 42)
        #expect(components(dates[0]) == [2026, 8, 30])
        #expect(components(dates[41]) == [2026, 10, 10])
    }

    @Test func shiftsMonthAndYearWhilePreservingDay() throws {
        let month = try #require(CalendarGridNavigator.shiftedSelection(
            date: date(2026, 8, 15),
            displayedMonth: date(2026, 8, 1),
            component: .month,
            value: 1,
            calendar: calendar
        ))
        #expect(components(month.date) == [2026, 9, 15])

        let year = try #require(CalendarGridNavigator.shiftedSelection(
            date: date(2024, 2, 29),
            displayedMonth: date(2024, 2, 1),
            component: .year,
            value: 1,
            calendar: calendar
        ))
        #expect(components(year.date) == [2025, 2, 28])
    }

    private func moved(
        _ source: (Int, Int, Int),
        month: (Int, Int, Int),
        direction: Int
    ) throws -> [Int] {
        let move = try #require(CalendarGridNavigator.horizontalMove(
            from: date(source.0, source.1, source.2),
            displayedMonth: date(month.0, month.1, month.2),
            direction: direction,
            calendar: calendar
        ))
        return components(move.date)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func components(_ date: Date) -> [Int] {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return [parts.year, parts.month, parts.day].compactMap { $0 }
    }
}
