import Foundation

public struct DateTimeCandidateGenerator: Sendable {
    public struct Formats: Equatable, Sendable {
        public let date: [String]
        public let time: [String]
        public let dateTime: [String]

        public init(date: [String], time: [String], dateTime: [String]) {
            self.date = date
            self.time = time
            self.dateTime = dateTime
        }

        public static let `default` = Formats(
            date: ["YYYY年M月D日", "YYYY-MM-DD", "YYYY/MM/DD", "YYYYMMDD"],
            time: ["HH:mm", "HH:mm:ss", "H時m分", "H時m分s秒", "HHmm", "HHmmss"],
            dateTime: [
                "YYYY年M月D日 HH:mm",
                "YYYY-MM-DD HH:mm",
                "YYYY/MM/DD HH:mm",
                "YYYYMMDDHHmmss"
            ]
        )
    }

    public init() {}

    public func candidates(
        for reading: String,
        now: Date = Date(),
        calendar sourceCalendar: Calendar = .current,
        timeZone: TimeZone = .current,
        formats: Formats = .default
    ) -> [String] {
        let normalizedReading = reading.lowercased()
        var calendar = sourceCalendar
        calendar.timeZone = timeZone

        if let dayOffset = Self.dayOffsets[normalizedReading],
           let date = calendar.date(byAdding: .day, value: dayOffset, to: now) {
            return formattedCandidates(
                for: date,
                formats: formats.date,
                calendar: calendar
            )
        }

        if Self.timeReadings.contains(normalizedReading) {
            return formattedCandidates(
                for: now,
                formats: formats.time,
                calendar: calendar
            )
        }

        if Self.dateTimeReadings.contains(normalizedReading) {
            return formattedCandidates(
                for: now,
                formats: formats.dateTime,
                calendar: calendar
            )
        }

        return []
    }

    private func formattedCandidates(
        for date: Date,
        formats: [String],
        calendar: Calendar
    ) -> [String] {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour,
              let minute = components.minute,
              let second = components.second else {
            return []
        }

        let values = [
            "E": ["日", "月", "火", "水", "木", "金", "土"][
                max(calendar.component(.weekday, from: date) - 1, 0)
            ],
            "YYYY": String(format: "%04d", year),
            "YY": String(format: "%02d", year % 100),
            "MM": String(format: "%02d", month),
            "M": "\(month)",
            "DD": String(format: "%02d", day),
            "D": "\(day)",
            "HH": String(format: "%02d", hour),
            "H": "\(hour)",
            "mm": String(format: "%02d", minute),
            "m": "\(minute)",
            "ss": String(format: "%02d", second),
            "s": "\(second)"
        ]
        let tokens = [
            "YYYY", "YY", "MM", "DD", "HH", "mm", "ss",
            "M", "D", "H", "m", "s", "E"
        ]
        var seen = Set<String>()
        return formats.compactMap { format in
            var result = format
            for token in tokens {
                result = result.replacingOccurrences(
                    of: token,
                    with: values[token] ?? token
                )
            }
            guard !result.isEmpty, seen.insert(result).inserted else {
                return nil
            }
            return result
        }
    }

    private static let dayOffsets = [
        "ototoi": -2,
        "kinou": -1,
        "kyou": 0,
        "ashita": 1,
        "asatte": 2
    ]

    private static let timeReadings: Set<String> = [
        "ima", "jikoku", "genzaijikoku"
    ]

    private static let dateTimeReadings: Set<String> = [
        "nichiji", "genzainichiji"
    ]
}
