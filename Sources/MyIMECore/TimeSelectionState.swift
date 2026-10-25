import Foundation

public enum TimePeriod: Equatable, Sendable {
    case am
    case pm
}

public enum TimeInputStage: Equatable, Sendable {
    case period
    case hour
    case minute
}

public enum TimeDialSelection: Equatable, Sendable {
    case period(TimePeriod)
    case hour(Int)
    case minute(Int)
}

public enum TimeDialArrowDirection: CaseIterable, Equatable, Sendable {
    case left
    case right
    case up
    case down

    fileprivate var vector: (x: Double, y: Double) {
        switch self {
        case .left: (-1, 0)
        case .right: (1, 0)
        case .up: (0, 1)
        case .down: (0, -1)
        }
    }
}

/// Sizes of the compact, single-circle time panel in points
public struct TimeDialLayout: Equatable, Sendable {
    public var panelWidth: Double = 332
    public var panelHeight: Double = 430
    public var dialRadius: Double = 130
    public var outerRadius: Double = 122
    public var labelRadius: Double = 96
    public var innerHitRadius: Double = 64
    public var labelFontSize: Double = 17
    public var periodFontSize: Double = 22
    public var headingFontSize: Double = 15
    public var summaryFontSize: Double = 16
    public var highlightRadius: Double = 17

    public init() {}

    public func label(atDialStep step: Int, stage: TimeInputStage) -> String {
        switch stage {
        case .period:
            step == 0 ? "AM" : "PM"
        case .hour:
            String(step == 0 ? 12 : step)
        case .minute:
            String(format: "%02d", step * 5)
        }
    }

    public func labelCenter(
        atDialStep step: Int,
        stage: TimeInputStage
    ) -> (x: Double, y: Double) {
        if stage == .period {
            return (0, step == 0 ? 52 : -52)
        }
        let radians = Double(step) * .pi / 6
        return (
            sin(radians) * labelRadius,
            cos(radians) * labelRadius
        )
    }

    public func selection(
        atX x: Double,
        y: Double,
        stage: TimeInputStage
    ) -> TimeDialSelection? {
        let distance = hypot(x, y)
        guard distance <= outerRadius else { return nil }
        if stage == .period {
            return .period(y >= 0 ? .am : .pm)
        }
        guard distance >= innerHitRadius else { return nil }
        var angle = atan2(x, y)
        if angle < 0 { angle += 2 * .pi }
        let step = Int((angle / (.pi / 6)).rounded()) % 12
        switch stage {
        case .period:
            return nil
        case .hour:
            return .hour(step == 0 ? 12 : step)
        case .minute:
            return .minute(step * 5)
        }
    }

    /// Moves to one adjacent dial position only when the arrow points
    /// unambiguously toward it
    public func adjacentStep(
        from step: Int,
        direction: TimeDialArrowDirection
    ) -> Int? {
        guard (0..<12).contains(step) else { return nil }
        let clockwise = (step + 1) % 12
        let counterclockwise = (step + 11) % 12
        let current = unitPoint(at: step)
        let arrow = direction.vector
        let clockwisePoint = unitPoint(at: clockwise)
        let counterclockwisePoint = unitPoint(at: counterclockwise)
        let clockwiseDot = (clockwisePoint.x - current.x) * arrow.x
            + (clockwisePoint.y - current.y) * arrow.y
        let counterclockwiseDot =
            (counterclockwisePoint.x - current.x) * arrow.x
            + (counterclockwisePoint.y - current.y) * arrow.y
        let epsilon = 1e-10
        let movesClockwise = clockwiseDot > epsilon
        let movesCounterclockwise = counterclockwiseDot > epsilon
        guard movesClockwise != movesCounterclockwise else { return nil }
        return movesClockwise ? clockwise : counterclockwise
    }

    private func unitPoint(at step: Int) -> (x: Double, y: Double) {
        let radians = Double(step) * .pi / 6
        return (sin(radians), cos(radians))
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

    public var period: TimePeriod { hour < 12 ? .am : .pm }

    public var twelveHour: Int {
        let value = hour % 12
        return value == 0 ? 12 : value
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

    public mutating func selectPeriod(_ period: TimePeriod) {
        let value = twelveHour
        hour = switch period {
        case .am: value == 12 ? 0 : value
        case .pm: value == 12 ? 12 : value + 12
        }
    }

    public mutating func selectTwelveHour(_ value: Int) {
        guard (1...12).contains(value) else { return }
        hour = switch period {
        case .am: value == 12 ? 0 : value
        case .pm: value == 12 ? 12 : value + 12
        }
    }

    public mutating func selectMinute(_ minute: Int) {
        guard minute.isMultiple(of: 5) else { return }
        _ = set(minute: minute)
    }

    public func roundedToNearestFiveMinutes() -> TimeSelectionState {
        let total = (hour * 60 + minute + 2) / 5 * 5
        let wrapped = total % (24 * 60)
        return TimeSelectionState(hour: wrapped / 60, minute: wrapped % 60)!
    }

    public var digitalText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

public struct TimeInputFlow: Equatable, Sendable {
    public private(set) var stage: TimeInputStage
    public private(set) var time: TimeSelectionState

    public init(
        time: TimeSelectionState,
        stage: TimeInputStage = .period
    ) {
        self.time = time
        self.stage = stage
    }

    /// Returns the completed time only after the minute is selected
    public mutating func select(
        _ selection: TimeDialSelection
    ) -> TimeSelectionState? {
        switch (stage, selection) {
        case let (.period, .period(period)):
            time.selectPeriod(period)
            stage = .hour
        case let (.hour, .hour(hour)) where (1...12).contains(hour):
            time.selectTwelveHour(hour)
            stage = .minute
        case let (.minute, .minute(minute))
            where (0...55).contains(minute) && minute.isMultiple(of: 5):
            time.selectMinute(minute)
            return time
        default:
            break
        }
        return nil
    }

    /// Returns false only when Esc should close the whole time panel
    @discardableResult
    public mutating func moveBack() -> Bool {
        switch stage {
        case .period:
            return false
        case .hour:
            stage = .period
        case .minute:
            stage = .hour
        }
        return true
    }

    public mutating func restart() {
        stage = .period
    }

    /// Changes only the current selection; Enter or a pointer selection
    /// advances to the next stage
    @discardableResult
    public mutating func moveSelection(
        _ direction: TimeDialArrowDirection,
        layout: TimeDialLayout = TimeDialLayout()
    ) -> Bool {
        switch stage {
        case .period:
            let period: TimePeriod = switch direction {
            case .left, .up: .am
            case .right, .down: .pm
            }
            let changed = time.period != period
            time.selectPeriod(period)
            return changed
        case .hour:
            let currentStep = time.twelveHour % 12
            guard let step = layout.adjacentStep(
                from: currentStep,
                direction: direction
            ) else { return false }
            time.selectTwelveHour(step == 0 ? 12 : step)
            return true
        case .minute:
            let currentStep = time.minute / 5
            guard let step = layout.adjacentStep(
                from: currentStep,
                direction: direction
            ) else { return false }
            time.selectMinute(step * 5)
            return true
        }
    }

    /// Confirms the value already highlighted by keyboard navigation
    public mutating func confirmCurrentSelection() -> TimeSelectionState? {
        switch stage {
        case .period:
            return select(.period(time.period))
        case .hour:
            return select(.hour(time.twelveHour))
        case .minute:
            return select(.minute(time.minute))
        }
    }
}
