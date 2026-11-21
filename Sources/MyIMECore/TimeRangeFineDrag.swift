/// The fixed 60-minute window used while a physical handle is held still
///
/// AppKit owns the timer and pointer events  This value owns all coordinate,
/// accumulation, rounding and boundary calculations used by the view
public struct TimeRangeFineDrag: Equatable, Sendable {
    public static let windowMinutes = 60

    public let handle: TimeInputState.Handle
    public let windowStart: Double
    private let railWidth: Double
    private var lastX: Double
    private var exactMinutes: Double

    public init(
        handle: TimeInputState.Handle,
        state: TimeInputState,
        knobFraction: Double,
        cursorX: Double,
        railWidth: Double
    ) {
        self.handle = handle
        let minutes = Double(state.minutes(of: handle))
        let unclampedStart = minutes
            - Double(Self.windowMinutes) * knobFraction
        windowStart = min(
            max(unclampedStart, 0),
            Double(TimeRangeSelection.dayMinutes - Self.windowMinutes)
        )
        self.railWidth = max(railWidth, 1)
        lastX = cursorX
        exactMinutes = minutes
    }

    public var windowEnd: Double { windowStart + Double(Self.windowMinutes) }

    public func fraction(forMinutes minutes: Double) -> Double {
        (minutes - windowStart) / Double(Self.windowMinutes)
    }

    public func contains(minutes: Int) -> Bool {
        Double(minutes) >= windowStart && Double(minutes) <= windowEnd
    }

    /// Moves the held physical handle while preserving movement below one
    /// selectable step and keeping the zoom window fixed across a crossing
    @discardableResult
    public mutating func drag(
        toX x: Double,
        state: inout TimeInputState
    ) -> Bool {
        let delta = (x - lastX) * Double(Self.windowMinutes) / railWidth
        lastX = x
        let bounds = allowedMinutes(in: state)
        exactMinutes = min(max(exactMinutes + delta, bounds.lowerBound),
                           bounds.upperBound)
        return state.move(handle, to: exactMinutes)
    }

    private func allowedMinutes(
        in state: TimeInputState
    ) -> ClosedRange<Double> {
        let stateBounds = state.allowedMinutes(for: handle)
        let lower = max(windowStart, Double(stateBounds.lowerBound))
        let upper = min(windowEnd, Double(stateBounds.upperBound))
        let step = Double(TimeRangeSelection.dragStep)
        let low = (lower / step).rounded(.up) * step
        let high = (upper / step).rounded(.down) * step
        let current = Double(state.minutes(of: handle))
        return low <= high ? low...high : current...current
    }
}
