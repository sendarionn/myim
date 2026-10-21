import Foundation

public enum TimeDialComponent: Equatable, Sendable {
    case hour
    case minute
}

public struct TimeSelectionState: Equatable, Sendable {
    public private(set) var hour: Int
    public private(set) var minute: Int
    public var dialComponent: TimeDialComponent

    public init?(
        hour: Int,
        minute: Int,
        dialComponent: TimeDialComponent = .hour
    ) {
        guard Self.isValid(hour: hour, minute: minute) else { return nil }
        self.hour = hour
        self.minute = minute
        self.dialComponent = dialComponent
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

    public mutating func setPM(_ isPM: Bool) {
        hour = hour % 12 + (isPM ? 12 : 0)
    }

    public mutating func selectHour(atClockAngle angle: Double) {
        let clockHour = Self.nearestDialStep(atClockAngle: angle)
        let hourInPeriod = clockHour == 12 ? 0 : clockHour
        hour = hourInPeriod + (hour >= 12 ? 12 : 0)
    }

    public mutating func selectMinute(atClockAngle angle: Double) {
        minute = (Self.nearestDialStep(atClockAngle: angle) % 12) * 5
    }

    public var hourHandAngle: Double {
        (Double(hour % 12) + Double(minute) / 60) * 30
    }

    public var minuteHandAngle: Double {
        Double(minute) * 6
    }

    public var isPM: Bool { hour >= 12 }

    public var digitalText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    private static func nearestDialStep(atClockAngle angle: Double) -> Int {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        let step = Int((positive / 30).rounded()) % 12
        return step == 0 ? 12 : step
    }
}
