import Foundation

/// The 24-hour dial shows 1 to 12 on the inner ring and 13 to 24 on the
/// outer ring, 24 standing for 00 since no time is kept as 24:xx
public enum TimeHourRing: Equatable, Sendable {
    case outer
    case inner

    public init(hour: Int) {
        self = hour == 0 || hour >= 13 ? .outer : .inner
    }

    /// The hour at the 12 dial positions, 0 being the 12 o'clock position
    public func hour(atDialStep step: Int) -> Int {
        switch self {
        case .inner:
            step == 0 ? 12 : step
        case .outer:
            step == 0 ? 0 : step + 12
        }
    }

    public func label(atDialStep step: Int) -> String {
        switch self {
        case .inner:
            String(step == 0 ? 12 : step)
        case .outer:
            String(step == 0 ? 24 : step + 12)
        }
    }
}

public enum TimeClockHand: Equatable, Sendable {
    case hour
    case minute
}

public enum TimeClockInteractionGeometry {
    public static func dragTarget(
        x: Double,
        y: Double,
        radius: Double,
        state: TimeSelectionState,
        tolerance: Double = 8
    ) -> TimeClockHand? {
        guard radius > 0, hypot(x, y) > 9 else { return nil }
        let hourEnd = endpoint(
            angleDegrees: state.hourHandAngle,
            length: radius * 0.48
        )
        let minuteEnd = endpoint(
            angleDegrees: state.minuteHandAngle,
            length: radius * 0.68
        )
        let hourDistance = distanceToSegment(
            x: x,
            y: y,
            endX: hourEnd.x,
            endY: hourEnd.y
        )
        let minuteDistance = distanceToSegment(
            x: x,
            y: y,
            endX: minuteEnd.x,
            endY: minuteEnd.y
        )
        switch (hourDistance <= tolerance, minuteDistance <= tolerance) {
        case (true, false):
            return .hour
        case (false, true):
            return .minute
        case (true, true):
            return hypot(x - hourEnd.x, y - hourEnd.y)
                <= hypot(x - minuteEnd.x, y - minuteEnd.y)
                ? .hour
                : .minute
        case (false, false):
            return nil
        }
    }

    public static func hourRing(
        distanceRatio: Double,
        current: TimeHourRing
    ) -> TimeHourRing {
        if distanceRatio >= 0.74 { return .outer }
        if (0.56...0.66).contains(distanceRatio) { return .inner }
        return current
    }

    private static func endpoint(
        angleDegrees: Double,
        length: Double
    ) -> (x: Double, y: Double) {
        let radians = angleDegrees * .pi / 180
        return (sin(radians) * length, cos(radians) * length)
    }

    private static func distanceToSegment(
        x: Double,
        y: Double,
        endX: Double,
        endY: Double
    ) -> Double {
        let lengthSquared = endX * endX + endY * endY
        guard lengthSquared > 0 else { return hypot(x, y) }
        let projection = max(
            0,
            min(1, (x * endX + y * endY) / lengthSquared)
        )
        return hypot(x - projection * endX, y - projection * endY)
    }
}

public struct TimeSelectionState: Equatable, Sendable {
    public private(set) var hour: Int
    public private(set) var minute: Int

    public init?(hour: Int, minute: Int) {
        guard Self.isValid(hour: hour, minute: minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public static func isValid(hour: Int, minute: Int) -> Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }

    @discardableResult
    public mutating func set(hour: Int) -> Bool {
        guard (0...23).contains(hour) else { return false }
        self.hour = hour
        return true
    }

    @discardableResult
    public mutating func set(minute: Int) -> Bool {
        guard (0...59).contains(minute) else { return false }
        self.minute = minute
        return true
    }

    public mutating func selectHour(
        atClockAngle angle: Double,
        ring: TimeHourRing
    ) {
        hour = ring.hour(atDialStep: Self.nearestDialStep(atClockAngle: angle))
    }

    public mutating func selectMinute(atClockAngle angle: Double) {
        minute = Self.nearestDialStep(atClockAngle: angle) * 5
    }

    public var hourHandAngle: Double {
        (Double(hour % 12) + Double(minute) / 60) * 30
    }

    public var minuteHandAngle: Double {
        Double(minute) * 6
    }

    public var digitalText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    private static func nearestDialStep(atClockAngle angle: Double) -> Int {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        return Int((positive / 30).rounded()) % 12
    }
}
