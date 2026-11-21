/// The value selected by the unified time rail
///
/// Handles identify the two physical knobs and do not change while they are
/// operated  Their chronological start/end roles change only after one handle
/// moves beyond the other
public struct TimeInputState: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case time
        case range
    }

    public enum Handle: CaseIterable, Equatable, Sendable {
        case upper
        case lower
    }

    public enum Role: Equatable, Sendable {
        case start
        case end
    }

    public private(set) var mode: Mode
    public private(set) var upperMinutes: Int
    public private(set) var lowerMinutes: Int
    private var upperRoleAtEquality: Role

    public init(time: TimeSelectionState) {
        let minutes = Self.roundedTimeMinutes(time.hour * 60 + time.minute)
        mode = .time
        upperMinutes = minutes
        lowerMinutes = minutes
        upperRoleAtEquality = .start
    }

    public init(range: TimeRangeSelection) {
        mode = .range
        upperMinutes = range.start
        lowerMinutes = range.end
        upperRoleAtEquality = .start
    }

    public var start: Int { min(upperMinutes, lowerMinutes) }
    public var end: Int { max(upperMinutes, lowerMinutes) }

    public var timeSelection: TimeSelectionState? {
        guard mode == .time else { return nil }
        return TimeSelectionState(
            hour: upperMinutes / 60,
            minute: upperMinutes % 60
        )
    }

    public var rangeSelection: TimeRangeSelection? {
        guard mode == .range else { return nil }
        return TimeRangeSelection(start: start, end: end)
    }

    public func minutes(of handle: Handle) -> Int {
        handle == .upper ? upperMinutes : lowerMinutes
    }

    public func minutes(for role: Role) -> Int {
        role == .start ? start : end
    }

    public func role(of handle: Handle) -> Role {
        if upperMinutes == lowerMinutes {
            return handle == .upper
                ? upperRoleAtEquality
                : Self.opposite(upperRoleAtEquality)
        }
        let upperIsStart = upperMinutes < lowerMinutes
        if handle == .upper {
            return upperIsStart ? .start : .end
        }
        return upperIsStart ? .end : .start
    }

    public func handle(for role: Role) -> Handle {
        self.role(of: .upper) == role ? .upper : .lower
    }

    public func allowedMinutes(for handle: Handle) -> ClosedRange<Int> {
        if mode == .time, handle == .upper {
            return 0...(TimeRangeSelection.dayMinutes - TimeRangeSelection.dragStep)
        }
        return 0...TimeRangeSelection.dayMinutes
    }

    /// Applies a raw drag value after rounding it to the selectable step
    @discardableResult
    public mutating func move(_ handle: Handle, to minutes: Double) -> Bool {
        let step = Double(TimeRangeSelection.dragStep)
        let rounded = Int((minutes / step).rounded() * step)
        let bounds = allowedMinutes(for: handle)
        return set(
            handle,
            to: min(max(rounded, bounds.lowerBound), bounds.upperBound)
        )
    }

    /// Applies a value already expressed in minutes
    @discardableResult
    public mutating func set(_ handle: Handle, to minutes: Int) -> Bool {
        guard minutes.isMultiple(of: TimeRangeSelection.dragStep),
              allowedMinutes(for: handle).contains(minutes) else {
            return false
        }

        let previous = self.minutes(of: handle)
        guard previous != minutes else { return false }

        if mode == .time, handle == .upper {
            upperMinutes = minutes
            lowerMinutes = minutes
            upperRoleAtEquality = .start
            return true
        }

        let oldUpperRole = role(of: .upper)
        switch handle {
        case .upper:
            upperMinutes = minutes
        case .lower:
            lowerMinutes = minutes
            if mode == .time { mode = .range }
        }

        if upperMinutes == lowerMinutes {
            upperRoleAtEquality = oldUpperRole
        } else {
            upperRoleAtEquality = upperMinutes < lowerMinutes ? .start : .end
        }
        return true
    }

    @discardableResult
    public mutating func move(_ handle: Handle, by delta: Int) -> Bool {
        let bounds = allowedMinutes(for: handle)
        let value = min(max(minutes(of: handle) + delta, bounds.lowerBound),
                        bounds.upperBound)
        return set(handle, to: value)
    }

    /// Leaves range editing without discarding its chronological start
    @discardableResult
    public mutating func returnToTimeMode() -> Bool {
        guard mode == .range else { return false }
        let time = start
        mode = .time
        upperMinutes = time
        lowerMinutes = time
        upperRoleAtEquality = .start
        return true
    }

    private static func roundedTimeMinutes(_ minutes: Int) -> Int {
        let step = Double(TimeRangeSelection.dragStep)
        return min(
            max(Int((Double(minutes) / step).rounded()) * TimeRangeSelection.dragStep, 0),
            TimeRangeSelection.dayMinutes - TimeRangeSelection.dragStep
        )
    }

    private static func opposite(_ role: Role) -> Role {
        role == .start ? .end : .start
    }
}
