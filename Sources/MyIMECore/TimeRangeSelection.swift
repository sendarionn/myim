/// A time range within one day, in minutes from 0:00, with the start
/// before the end; the end may be 24:00
public struct TimeRangeSelection: Equatable, Sendable {
    public enum Edge: Equatable, Sendable {
        case start
        case end
    }

    public static let dayMinutes = 24 * 60
    /// Every input path uses the same five-minute step
    public static let dragStep = 5

    public private(set) var start: Int
    public private(set) var end: Int

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

    public func minutes(of edge: Edge) -> Int {
        edge == .start ? start : end
    }

    /// Moves one end, stopping one selectable step away from the other end
    public mutating func move(_ edge: Edge, to minutes: Int) {
        switch edge {
        case .start:
            start = min(max(Self.roundToStep(minutes), 0), end - Self.dragStep)
        case .end:
            end = max(
                min(Self.roundToStep(minutes), Self.dayMinutes),
                start + Self.dragStep
            )
        }
    }

    /// Moves one end to a position on the 0:00 to 24:00 rail, from 0 to 1
    public mutating func drag(_ edge: Edge, toFraction fraction: Double) {
        let minutes = fraction * Double(Self.dayMinutes)
        let step = Double(Self.dragStep)
        move(edge, to: Int((minutes / step).rounded() * step))
    }

    /// Sets one end from typed text; false, with nothing changed, when the
    /// text is not a time or would not keep the start before the end
    @discardableResult
    public mutating func set(_ edge: Edge, text: String) -> Bool {
        guard let minutes = Self.minutes(from: text),
              minutes.isMultiple(of: Self.dragStep) else { return false }
        switch edge {
        case .start:
            guard minutes < end else { return false }
            start = minutes
        case .end:
            guard minutes > start else { return false }
            end = minutes
        }
        return true
    }

    /// `13:05`, `1305`, `9:05`, `905`, `13` or `9`; 24:00 is the only
    /// time after 23:59
    public static func minutes(from text: String) -> Int? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        let hourText: Substring
        let minuteText: Substring
        switch parts.count {
        case 1 where text.count >= 3:
            hourText = text.dropLast(2)
            minuteText = text.suffix(2)
        case 1:
            hourText = Substring(text)
            minuteText = "00"
        case 2:
            hourText = parts[0]
            minuteText = parts[1]
        default:
            return nil
        }
        guard (1...2).contains(hourText.count),
              minuteText.count == 2,
              hourText.allSatisfy(\.isASCII), minuteText.allSatisfy(\.isASCII),
              let hour = Int(hourText), let minute = Int(minuteText),
              (0...59).contains(minute) else {
            return nil
        }
        let minutes = hour * 60 + minute
        return minutes <= dayMinutes ? minutes : nil
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
