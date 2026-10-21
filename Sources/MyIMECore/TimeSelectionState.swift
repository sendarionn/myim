import Foundation

/// The 12 labels the dial shows at a time
///
/// The pages split the hours as 1 to 12 and 13 to 24, not as morning and
/// afternoon: AM holds 1 to 12 o'clock, PM holds 13 to 23 o'clock and 24,
/// which stands for 0 o'clock since no time is kept as 24:xx
public enum TimeDialPage: Equatable, Sendable {
    case am
    case pm

    /// The page that shows `hour`
    public init(hour: Int) {
        self = (1...12).contains(hour) ? .am : .pm
    }

    /// The hour of the label at one of the 12 positions, 0 being the top
    public func hour(atDialStep step: Int) -> Int {
        switch self {
        case .am:
            step == 0 ? 12 : step
        case .pm:
            step == 0 ? 0 : step + 12
        }
    }

    public func label(atDialStep step: Int) -> String {
        switch self {
        case .am:
            String(step == 0 ? 12 : step)
        case .pm:
            String(step == 0 ? 24 : step + 12)
        }
    }
}

/// Sizes of the dial in points; drawing and hit testing both read them, so
/// a label is chosen where it is drawn
public struct TimeDialLayout: Equatable, Sendable {
    public var labelFontSize: Double = 15
    /// Radius of a label's highlight and of the area that clicks it
    public var labelHitRadius: Double = 18
    public var labelRingRadius: Double = 92
    public var margin: Double = 8
    /// How far from the minute hand a press still grabs it
    public var minuteHandTolerance: Double = 10

    public init() {}

    public var dialRadius: Double { labelRingRadius + labelHitRadius + margin }
    /// Ends short of the labels, so grabbing it never competes with them
    public var minuteHandLength: Double {
        labelRingRadius - labelHitRadius - 4
    }
    public var hourHandLength: Double { minuteHandLength * 0.65 }

    /// Offset of a label's centre from the dial centre, y pointing up
    public func labelCenter(atDialStep step: Int) -> (x: Double, y: Double) {
        let radians = Double(step) * .pi / 6
        return (sin(radians) * labelRingRadius, cos(radians) * labelRingRadius)
    }

    /// The label position a press at (x, y) from the centre clicks
    public func labelStep(atX x: Double, y: Double) -> Int? {
        (0..<12).first { step in
            let center = labelCenter(atDialStep: step)
            return hypot(x - center.x, y - center.y) <= labelHitRadius
        }
    }

    /// Whether a press at (x, y) grabs the minute hand; labels come first
    public func grabsMinuteHand(
        atX x: Double,
        y: Double,
        state: TimeSelectionState
    ) -> Bool {
        guard labelStep(atX: x, y: y) == nil, hypot(x, y) > 6 else {
            return false
        }
        let radians = state.minuteHandAngle * .pi / 180
        let endX = sin(radians) * minuteHandLength
        let endY = cos(radians) * minuteHandLength
        let lengthSquared = endX * endX + endY * endY
        let projection = max(0, min(1, (x * endX + y * endY) / lengthSquared))
        return hypot(x - projection * endX, y - projection * endY)
            <= minuteHandTolerance
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

    /// Selects the hour of a clicked label, keeping the minute
    public mutating func selectHour(atDialStep step: Int, page: TimeDialPage) {
        hour = page.hour(atDialStep: step)
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
