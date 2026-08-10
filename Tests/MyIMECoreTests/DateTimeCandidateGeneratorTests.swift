import Foundation
import Testing
@testable import MyIMECore

@Suite
struct DateTimeCandidateGeneratorTests {
    private let generator = DateTimeCandidateGenerator()
    private let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    @Test
    func generatesSeveralFormatsForToday() {
        #expect(generator.candidates(
            for: "kyou",
            now: fixedDate,
            calendar: calendar,
            timeZone: timeZone
        ) == [
            "2026年8月10日",
            "2026-08-10",
            "2026/08/10",
            "20260810"
        ])
    }

    @Test
    func appliesRelativeDayOffsets() {
        #expect(generator.candidates(
            for: "kinou",
            now: fixedDate,
            calendar: calendar,
            timeZone: timeZone
        ).first == "2026年8月9日")
        #expect(generator.candidates(
            for: "ashita",
            now: fixedDate,
            calendar: calendar,
            timeZone: timeZone
        ).first == "2026年8月11日")
    }

    @Test
    func generatesSeveralFormatsForCurrentTime() {
        #expect(generator.candidates(
            for: "ima",
            now: fixedDate,
            calendar: calendar,
            timeZone: timeZone
        ) == [
            "16:59",
            "16:59:12",
            "16時59分",
            "16時59分12秒",
            "1659",
            "165912"
        ])
    }

    @Test
    func ignoresOrdinaryReadings() {
        #expect(generator.candidates(
            for: "tokyou",
            now: fixedDate,
            calendar: calendar,
            timeZone: timeZone
        ).isEmpty)
    }

    @Test
    func appliesConfiguredFormatsInOrder() {
        let formats = DateTimeCandidateGenerator.Formats(
            date: ["YYYYMMDD", "YY-M-D"],
            time: ["HHmmss"],
            dateTime: ["YYYY-MM-DD HH:mm"]
        )
        #expect(generator.candidates(
            for: "kyou",
            now: fixedDate,
            calendar: calendar,
            timeZone: timeZone,
            formats: formats
        ) == ["20260810", "26-8-10"])
        #expect(generator.candidates(
            for: "jikoku",
            now: fixedDate,
            calendar: calendar,
            timeZone: timeZone,
            formats: formats
        ) == ["165912"])
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private var fixedDate: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 10,
            hour: 16,
            minute: 59,
            second: 12
        ))!
    }
}
