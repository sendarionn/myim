/// The rail of a time range showing one hour while a knob is held still,
/// so the knob moves by the minute; it starts with the knob where it was on
/// the whole day, and only horizontal movement after that changes the time
public struct TimeRangeFineDrag: Equatable, Sendable {
    public static let windowMinutes = 60

    public let edge: TimeRangeSelection.Edge
    /// The time at the left end of the rail; may lie before 0:00 or end
    /// after 24:00, which cannot be chosen
    public let windowStart: Double
    private let railWidth: Double
    private var lastX: Double
    /// Kept below the minute so small movements add up
    private var exactMinutes: Double

    /// `knobFraction` is where the knob is on the rail, from 0 to 1, and
    /// `cursorX` where the cursor is when the rail changes
    public init(
        edge: TimeRangeSelection.Edge,
        range: TimeRangeSelection,
        knobFraction: Double,
        cursorX: Double,
        railWidth: Double
    ) {
        self.edge = edge
        let minutes = Double(range.minutes(of: edge))
        windowStart = minutes - Double(Self.windowMinutes) * knobFraction
        self.railWidth = max(railWidth, 1)
        lastX = cursorX
        exactMinutes = minutes
    }

    public var windowEnd: Double { windowStart + Double(Self.windowMinutes) }

    /// Where `minutes` is on the rail, from 0 to 1; outside it when the
    /// time is not shown
    public func fraction(forMinutes minutes: Double) -> Double {
        (minutes - windowStart) / Double(Self.windowMinutes)
    }

    public func contains(minutes: Int) -> Bool {
        Double(minutes) >= windowStart && Double(minutes) <= windowEnd
    }

    /// Moves the held end by the cursor's horizontal movement since the last
    /// call; movement past the shown hour, the day or the other end is not
    /// kept, so turning back moves the knob at once
    public mutating func drag(toX x: Double, range: inout TimeRangeSelection) {
        let delta = (x - lastX) * Double(Self.windowMinutes) / railWidth
        lastX = x
        let bounds = allowedMinutes(in: range)
        exactMinutes = min(max(exactMinutes + delta, bounds.lowerBound),
                           bounds.upperBound)
        range.move(edge, to: Int(exactMinutes.rounded()))
    }

    private func allowedMinutes(
        in range: TimeRangeSelection
    ) -> ClosedRange<Double> {
        let lower: Double
        let upper: Double
        switch edge {
        case .start:
            lower = max(windowStart, 0)
            upper = min(windowEnd, Double(range.end - 1))
        case .end:
            lower = max(windowStart, Double(range.start + 1))
            upper = min(windowEnd, Double(TimeRangeSelection.dayMinutes))
        }
        // Whole minutes, so rounding never leaves the bounds
        let low = lower.rounded(.up)
        let high = upper.rounded(.down)
        let current = Double(range.minutes(of: edge))
        return low <= high ? low...high : current...current
    }
}
