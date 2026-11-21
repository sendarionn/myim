/// A time range within one day, in minutes from 0:00, with the start
/// before the end; the end may be 24:00
public struct TimeRangeSelection: Equatable, Sendable {
    public static let dayMinutes = 24 * 60
    /// Every selection path uses the same five-minute step
    public static let dragStep = 5

    public let start: Int
    public let end: Int

    public init?(start: Int, end: Int) {
        guard 0 <= start, start + Self.dragStep <= end,
              end <= Self.dayMinutes,
              start.isMultiple(of: Self.dragStep),
              end.isMultiple(of: Self.dragStep) else {
            return nil
        }
        self.start = start
        self.end = end
    }

    /// Starts at `time` and ends an hour later, or at 24:00
    public init(startingAt time: TimeSelectionState) {
        start = min(
            Self.roundToStep(time.hour * 60 + time.minute),
            Self.dayMinutes - Self.dragStep
        )
        end = min(start + 60, Self.dayMinutes)
    }

    /// `HH:MM`, as the clock shows a time
    public static func text(forMinutes minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        return (hour < 10 ? "0" : "") + "\(hour):" + (minute < 10 ? "0" : "")
            + "\(minute)"
    }

    private static func roundToStep(_ minutes: Int) -> Int {
        Int((Double(minutes) / Double(dragStep)).rounded()) * dragStep
    }
}
