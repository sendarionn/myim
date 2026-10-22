import Foundation

/// The three fixed rings of the time dial, from outside to inside
public enum TimeDialRing: Equatable, Sendable, CaseIterable {
    case outerHour
    case middleHour
    case minute

    public func label(atDialStep step: Int) -> String {
        switch self {
        case .outerHour:
            String(step == 0 ? 12 : step)
        case .middleHour:
            String(step == 0 ? 24 : step + 12)
        case .minute:
            String(format: "%02d", step * 5)
        }
    }

    public func selection(atDialStep step: Int) -> TimeDialSelection {
        switch self {
        case .outerHour:
            .hour(step == 0 ? 12 : step)
        case .middleHour:
            .hour(step == 0 ? 0 : step + 12)
        case .minute:
            .minute(step * 5)
        }
    }
}

public enum TimeDialSelection: Equatable, Sendable {
    case hour(Int)
    case minute(Int)
}

/// Sizes of the round time panel in points
///
/// All three bands have the same width, and drawing and hit testing use the
/// same radii and angle calculation
public struct TimeDialLayout: Equatable, Sendable {
    public var labelFontSize: Double = 15
    public var highlightRadius: Double = 14
    public var outerRadius: Double = 180
    public var ringWidth: Double = 38
    public var margin: Double = 8
    public var timeDisplayFontSize: Double = 24

    public init() {}

    public var dialRadius: Double { outerRadius + margin }
    public var centerRadius: Double { outerRadius - ringWidth * 3 }

    public func outerRadius(of ring: TimeDialRing) -> Double {
        switch ring {
        case .outerHour: outerRadius
        case .middleHour: outerRadius - ringWidth
        case .minute: outerRadius - ringWidth * 2
        }
    }

    public func innerRadius(of ring: TimeDialRing) -> Double {
        outerRadius(of: ring) - ringWidth
    }

    public func labelRadius(of ring: TimeDialRing) -> Double {
        outerRadius(of: ring) - ringWidth / 2
    }

    /// Offset of a label's centre from the dial centre, y pointing up
    public func labelCenter(
        atDialStep step: Int,
        ring: TimeDialRing
    ) -> (x: Double, y: Double) {
        let radians = Double(step) * .pi / 6
        let radius = labelRadius(of: ring)
        return (sin(radians) * radius, cos(radians) * radius)
    }

    /// Returns the one non-overlapping annular sector containing the point
    public func selection(atX x: Double, y: Double) -> TimeDialSelection? {
        let distance = hypot(x, y)
        guard let ring = TimeDialRing.allCases.first(where: {
            distance > innerRadius(of: $0) && distance <= outerRadius(of: $0)
        }) else { return nil }

        var angle = atan2(x, y)
        if angle < 0 { angle += 2 * .pi }
        let step = Int((angle / (.pi / 6)).rounded()) % 12
        return ring.selection(atDialStep: step)
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

    public mutating func selectHour(_ hour: Int) {
        _ = set(hour: hour)
    }

    public mutating func selectMinute(_ minute: Int) {
        _ = set(minute: minute)
    }

    /// Rounds a newly opened clock to its closest five-minute value
    /// and carries 23:58 across midnight
    public func roundedToNearestFiveMinutes() -> TimeSelectionState {
        let total = (hour * 60 + minute + 2) / 5 * 5
        let wrapped = total % (24 * 60)
        return TimeSelectionState(hour: wrapped / 60, minute: wrapped % 60)!
    }

    public var digitalText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
