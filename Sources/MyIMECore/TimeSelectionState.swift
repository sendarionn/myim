import Foundation

/// The 24-hour dial shows 1 to 12 on the inner ring and 13 to 24 on the
/// outer ring, 24 standing for 0 o'clock since no time is kept as 24:xx
public enum TimeHourRing: Equatable, Sendable, CaseIterable {
    case inner
    case outer

    /// The hour of the label at one of the 12 positions, 0 being the top
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

/// Sizes of the round time panel in points, from the centre outwards: the
/// HH:MM fields, the ring dragged for minutes, then the inner and outer
/// hour labels; drawing and hit testing both read them, so every input
/// is judged around the centre it is drawn on
public struct TimeDialLayout: Equatable, Sendable {
    /// One size for both rings
    public var labelFontSize: Double = 15
    /// Radius of the round area that clicks a label; areas of neighbouring
    /// labels on either ring stay apart
    public var labelHitRadius: Double = 15
    /// Half the side of the square marking the selected hour, small enough
    /// that squares of labels diagonal to each other do not touch
    public var highlightHalfSide: Double = 11
    public var innerLabelRadius: Double = 110
    public var ringSpacing: Double = 36
    public var margin: Double = 8
    /// The HH:MM fields in the middle: two digit fields around a colon,
    /// kept small so the minute ring around them is wide
    public var digitFieldWidth: Double = 40
    public var digitSeparatorWidth: Double = 12
    public var digitFieldHeight: Double = 32
    /// Space kept between the minute ring and the fields and labels
    public var minuteRingGap: Double = 6

    public init() {}

    public var outerLabelRadius: Double { innerLabelRadius + ringSpacing }
    /// Radius of the round panel itself
    public var dialRadius: Double {
        outerLabelRadius + labelHitRadius + margin
    }

    /// Distance from the centre to a corner of the HH:MM fields
    public var digitAreaRadius: Double {
        hypot(
            digitFieldWidth + digitSeparatorWidth / 2,
            digitFieldHeight / 2
        )
    }

    /// The ring between the HH:MM fields and the inner labels where a
    /// press sets the minute
    public var minuteRingInnerRadius: Double {
        digitAreaRadius + minuteRingGap
    }
    public var minuteRingOuterRadius: Double {
        innerLabelRadius - labelHitRadius - minuteRingGap
    }

    public func labelRadius(of ring: TimeHourRing) -> Double {
        ring == .inner ? innerLabelRadius : outerLabelRadius
    }

    /// Offset of a label's centre from the dial centre, y pointing up
    public func labelCenter(
        atDialStep step: Int,
        ring: TimeHourRing
    ) -> (x: Double, y: Double) {
        let radians = Double(step) * .pi / 6
        let radius = labelRadius(of: ring)
        return (sin(radians) * radius, cos(radians) * radius)
    }

    /// The hour of the label whose click area holds (x, y)
    public func hour(atX x: Double, y: Double) -> Int? {
        for ring in TimeHourRing.allCases {
            for step in 0..<12 {
                let center = labelCenter(atDialStep: step, ring: ring)
                if hypot(x - center.x, y - center.y) <= labelHitRadius {
                    return ring.hour(atDialStep: step)
                }
            }
        }
        return nil
    }

    /// The minute pointed at from the centre: 0 at the top, 15 at the right
    public func minute(atX x: Double, y: Double) -> Int {
        var degrees = atan2(x, y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return Int((degrees / 6).rounded()) % 60
    }

    /// What a press at (x, y) operates
    public func region(atX x: Double, y: Double) -> TimeDialRegion {
        if let hour = hour(atX: x, y: y) { return .hourLabel(hour) }
        let distance = hypot(x, y)
        if distance < minuteRingInnerRadius { return .digits }
        if distance <= minuteRingOuterRadius { return .minuteRing }
        return .none
    }
}

public enum TimeDialRegion: Equatable, Sendable {
    case hourLabel(Int)
    case minuteRing
    /// The HH:MM fields, edited with the keyboard
    case digits
    case none
}

/// One press on the dial, its operation fixed by where it started: a
/// press on the minute ring sets the minute and follows the drag, and a
/// press on a label selects its hour when released over the same label
public struct TimeDialPointerGesture: Equatable, Sendable {
    public enum Release: Equatable, Sendable {
        case selectHour(Int)
        case none
    }

    public let region: TimeDialRegion

    public init(atX x: Double, y: Double, layout: TimeDialLayout) {
        region = layout.region(atX: x, y: y)
    }

    /// The minute set by pressing on the minute ring
    public func minuteOnPress(
        atX x: Double,
        y: Double,
        layout: TimeDialLayout
    ) -> Int? {
        region == .minuteRing ? layout.minute(atX: x, y: y) : nil
    }

    /// The minute while a press that started on the minute ring is dragged,
    /// wherever the pointer goes
    public func move(toX x: Double, y: Double, layout: TimeDialLayout) -> Int? {
        region == .minuteRing ? layout.minute(atX: x, y: y) : nil
    }

    public func release(
        atX x: Double,
        y: Double,
        layout: TimeDialLayout
    ) -> Release {
        guard case let .hourLabel(hour) = region,
              layout.hour(atX: x, y: y) == hour else { return .none }
        return .selectHour(hour)
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
    public mutating func selectHour(_ hour: Int) {
        _ = set(hour: hour)
    }

    public var digitalText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
