@preconcurrency import AppKit
import MyIMECore

private final class TimeHandleAccessibilityElement: NSAccessibilityElement {
    var incrementAction: (() -> Bool)?
    var decrementAction: (() -> Bool)?

    override func accessibilityPerformIncrement() -> Bool {
        incrementAction?() ?? false
    }

    override func accessibilityPerformDecrement() -> Bool {
        decrementAction?() ?? false
    }
}

/// A single 24-hour rail used for both a time and a time range
final class TimeRangeView: NSView {
    typealias Handle = TimeInputState.Handle
    typealias Role = TimeInputState.Role

    static let height: CGFloat = 132

    var timeAction: ((TimeSelectionState) -> Void)?
    var rangeAction: ((TimeRangeSelection) -> Void)?
    var cancelAction: (() -> Void)?

    private(set) var state = TimeInputState(
        time: TimeSelectionState(hour: 0, minute: 0)!
    )
    private var focusedHandle: Handle = .upper
    private var draggingHandle: Handle?
    private var dragOriginX: CGFloat = 0
    private var dragOriginMinutes: Double = 0
    private var exactDragMinutes: Double = 0
    private var fineDrag: TimeRangeFineDrag?
    private var stillnessTimer: Timer?
    private var stillOrigin: NSPoint = .zero
    private var stillSince: TimeInterval = 0
    private var lastDragPoint: NSPoint = .zero
    private static let stillDuration: TimeInterval = 0.4
    private static let stillTolerance: CGFloat = 3
    private static let step = TimeRangeSelection.dragStep

    private let previewElement = NSAccessibilityElement()
    private let upperKnobElement = TimeHandleAccessibilityElement()
    private let lowerKnobElement = TimeHandleAccessibilityElement()
    private let knobRadius: CGFloat = 7
    private let knobHitRadius: CGFloat = 14
    private let previewFont = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
    private let tickFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        previewElement.setAccessibilityRole(.staticText)
        previewElement.setAccessibilityLabel("選択時刻")
        previewElement.setAccessibilityParent(self)
        for (element, handle) in [(upperKnobElement, Handle.upper),
                                  (lowerKnobElement, .lower)] {
            element.setAccessibilityRole(.slider)
            element.setAccessibilityParent(self)
            element.incrementAction = { [weak self] in
                self?.adjust(handle, by: Self.step) ?? false
            }
            element.decrementAction = { [weak self] in
                self?.adjust(handle, by: -Self.step) ?? false
            }
        }
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    func begin(with time: TimeSelectionState) {
        state = TimeInputState(time: time)
        focusedHandle = .upper
        resetInteraction()
    }

    func begin(with range: TimeRangeSelection) {
        state = TimeInputState(range: range)
        focusedHandle = state.handle(for: .start)
        resetInteraction()
    }

    @discardableResult
    func returnToTimeMode() -> Bool {
        guard state.mode == .range else { return false }
        endDrag()
        _ = state.returnToTimeMode()
        focusedHandle = .upper
        updateAccessibility()
        needsDisplay = true
        return true
    }

    var isDragging: Bool { draggingHandle != nil }

    private func resetInteraction() {
        endDrag()
        updateAccessibility()
        needsDisplay = true
    }

    // MARK: Keys

    func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 53:
            cancelAction?()
        case 36, 76:
            confirm()
        case 48:
            focusedHandle = focusedHandle == .upper ? .lower : .upper
            updateAccessibility()
            needsDisplay = true
        case 123, 125:
            moveFocusedEdge(by: -Self.step)
        case 124, 126:
            moveFocusedEdge(by: Self.step)
        default:
            return
        }
    }

    override func keyDown(with event: NSEvent) { handleKey(event) }
    override func cancelOperation(_ sender: Any?) { cancelAction?() }

    private func moveFocusedEdge(by delta: Int) {
        _ = adjust(focusedHandle, by: delta)
    }

    @discardableResult
    private func adjust(_ handle: Handle, by delta: Int) -> Bool {
        focusedHandle = handle
        guard state.move(handle, by: delta) else { return false }
        updateAccessibility()
        needsDisplay = true
        return true
    }

    private func confirm() {
        switch state.mode {
        case .time:
            guard let time = state.timeSelection else { return }
            timeAction?(time)
        case .range:
            guard let range = state.rangeSelection else {
                NSSound.beep()
                return
            }
            rangeAction?(range)
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let handle = knobHandle(at: point) else { return }
        focusedHandle = handle
        draggingHandle = handle
        dragOriginX = point.x
        dragOriginMinutes = Double(state.minutes(of: handle))
        exactDragMinutes = dragOriginMinutes
        startStillnessTracking(at: point)
        updateAccessibility()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let handle = draggingHandle else { return }
        let point = convert(event.locationInWindow, from: nil)
        lastDragPoint = point
        if fineDrag != nil {
            dragFinely(to: point)
        } else {
            let delta = Double(point.x - dragOriginX)
                * Double(TimeRangeSelection.dayMinutes) / Double(max(railRect.width, 1))
            exactDragMinutes = dragOriginMinutes + delta
            applyDragged(exactDragMinutes, to: handle)
            if hypot(point.x - stillOrigin.x, point.y - stillOrigin.y) > Self.stillTolerance {
                stillOrigin = point
                stillSince = ProcessInfo.processInfo.systemUptime
            }
        }
    }

    override func mouseUp(with event: NSEvent) { endDrag() }

    func endDrag() {
        stillnessTimer?.invalidate()
        stillnessTimer = nil
        draggingHandle = nil
        if fineDrag != nil {
            fineDrag = nil
            updateAccessibility()
            needsDisplay = true
        }
    }

    private func startStillnessTracking(at point: NSPoint) {
        stillnessTimer?.invalidate()
        stillOrigin = point
        lastDragPoint = point
        stillSince = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkStillness()
        }
        stillnessTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .modalPanel)
        RunLoop.main.add(timer, forMode: .eventTracking)
    }

    private func checkStillness() {
        guard let handle = draggingHandle, fineDrag == nil else {
            stillnessTimer?.invalidate()
            stillnessTimer = nil
            return
        }
        guard ProcessInfo.processInfo.systemUptime - stillSince >= Self.stillDuration else { return }
        stillnessTimer?.invalidate()
        stillnessTimer = nil
        fineDrag = TimeRangeFineDrag(
            handle: handle,
            state: state,
            cursorX: Double(lastDragPoint.x),
            railWidth: Double(max(railRect.width, 1)),
        )
        updateAccessibility()
        needsDisplay = true
    }

    private func dragFinely(to point: NSPoint) {
        guard var fineDrag else { return }
        let changed = fineDrag.drag(toX: Double(point.x), state: &state)
        self.fineDrag = fineDrag
        guard changed else { return }
        updateAccessibility()
        needsDisplay = true
    }

    private func applyDragged(_ exactMinutes: Double, to handle: Handle) {
        guard state.move(handle, to: exactMinutes) else { return }
        updateAccessibility()
        needsDisplay = true
    }
    private func knobHandle(at point: NSPoint) -> Handle? {
        for handle in Handle.allCases where showsKnob(handle) {
            let center = knobCenter(for: handle)
            if hypot(point.x - center.x, point.y - center.y) <= knobHitRadius {
                return handle
            }
        }
        return nil
    }

    // MARK: Geometry and drawing

    private var railRect: NSRect {
        NSRect(x: 28, y: 18, width: 276, height: 56)
    }

    private var previewRect: NSRect {
        let textSize = (previewText as NSString).size(withAttributes: [.font: previewFont])
        let width = ceil(textSize.width) + 24
        return NSRect(x: bounds.midX - width / 2, y: 96, width: width, height: 30)
    }

    private func x(forMinutes minutes: Int) -> CGFloat {
        let rail = railRect
        let fraction = fineDrag?.fraction(forMinutes: Double(minutes))
            ?? Double(minutes) / Double(TimeRangeSelection.dayMinutes)
        return rail.minX + rail.width * CGFloat(fraction)
    }

    private func showsKnob(_ handle: Handle) -> Bool {
        guard let fineDrag, fineDrag.handle != handle else { return true }
        return fineDrag.contains(minutes: state.minutes(of: handle))
    }

    private func knobCenter(for handle: Handle) -> NSPoint {
        let rail = railRect
        return NSPoint(
            x: x(forMinutes: state.minutes(of: handle)),
            y: handle == .upper ? rail.maxY + 8 : rail.minY - 8
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawPreview()
        drawRail()
    }

    private var panelBackgroundColor: NSColor {
        NSColor(calibratedWhite: 0.18, alpha: 0.98)
    }

    private func drawPreview() {
        let panel = NSBezierPath(rect: previewRect)
        panelBackgroundColor.setFill()
        panel.fill()
        NSColor.separatorColor.setStroke()
        panel.lineWidth = 1
        panel.stroke()
        drawCentered(
            previewText,
            at: NSPoint(x: previewRect.midX, y: previewRect.midY),
            font: previewFont,
            color: .white
        )
    }

    private var previewText: String {
        let start = TimeRangeSelection.text(forMinutes: state.start)
        guard state.mode == .range else { return start }
        let end = TimeRangeSelection.text(forMinutes: state.end)
        return "\(start) 〜 \(end)"
    }

    private func drawRail() {
        let rail = railRect
        panelBackgroundColor.setFill()
        NSBezierPath(rect: rail).fill()
        if state.mode == .range, state.end > state.start {
            let startX = x(forMinutes: state.start)
            let endX = x(forMinutes: state.end)
            NSColor.controlAccentColor.withAlphaComponent(0.20).setFill()
            NSRect(
                x: startX,
                y: rail.minY,
                width: max(endX - startX, 0),
                height: rail.height
            ).fill()
        }

        NSColor.separatorColor.setStroke()
        for y in [rail.minY, rail.maxY] {
            let border = NSBezierPath()
            border.move(to: NSPoint(x: rail.minX, y: y))
            border.line(to: NSPoint(x: rail.maxX, y: y))
            border.lineWidth = 1
            border.stroke()
        }

        let ticks = tickMarks()
        for tick in ticks where !tick.isEndpoint {
            let tickX = x(forMinutes: tick.minutes)
            drawTickLine(atX: tickX, label: tick.label)
        }

        for handle in Handle.allCases where showsKnob(handle) {
            drawHandleLine(handle, ticks: ticks)
        }
        for tick in ticks {
            guard let label = tick.label else { continue }
            drawTickLabel(label, atX: x(forMinutes: tick.minutes), isEndpoint: tick.isEndpoint)
        }
        for handle in Handle.allCases where showsKnob(handle) {
            drawKnob(handle)
        }
    }

    private func drawTickLine(atX x: CGFloat, label: String?) {
        let rail = railRect
        let color = NSColor.white.withAlphaComponent(0.28)
        if let label {
            let rect = labelRect(label, atX: x)
            strokeVertical(x: x, from: rail.minY, to: rect.minY - 3, color: color)
            strokeVertical(x: x, from: rect.maxY + 3, to: rail.maxY, color: color)
        } else {
            strokeVertical(x: x, from: rail.minY, to: rail.minY + 8, color: color)
            strokeVertical(x: x, from: rail.maxY - 8, to: rail.maxY, color: color)
        }
    }

    private func drawHandleLine(_ handle: Handle, ticks: [TickMark]) {
        let center = knobCenter(for: handle)
        let rail = railRect
        let color = NSColor.controlAccentColor
        if handle == .upper {
            strokeVertical(x: center.x, from: rail.maxY, to: center.y, color: color, width: 1.5)
        } else {
            strokeVertical(x: center.x, from: center.y, to: rail.minY, color: color, width: 1.5)
        }
        let label = ticks.first(where: { $0.minutes == state.minutes(of: handle) })?.label
        if let label {
            let rect = labelRect(label, atX: center.x)
            strokeVertical(x: center.x, from: rail.minY, to: rect.minY - 3, color: color, width: 1.5)
            strokeVertical(x: center.x, from: rect.maxY + 3, to: rail.maxY, color: color, width: 1.5)
        } else {
            strokeVertical(x: center.x, from: rail.minY, to: rail.maxY, color: color, width: 1.5)
        }
    }

    private func drawKnob(_ handle: Handle) {
        let center = knobCenter(for: handle)
        let knob = NSBezierPath(ovalIn: NSRect(
            x: center.x - knobRadius,
            y: center.y - knobRadius,
            width: knobRadius * 2,
            height: knobRadius * 2
        ))
        if state.mode == .time, handle == .lower {
            NSColor.clear.setFill()
            knob.fill()
            NSColor.controlAccentColor.setStroke()
            knob.lineWidth = 1.5
            knob.stroke()
        } else {
            NSColor.controlAccentColor.setFill()
            knob.fill()
            if handle == focusedHandle {
                NSColor.white.setStroke()
                knob.lineWidth = 1.5
                knob.stroke()
            }
        }
    }

    private struct TickMark {
        let minutes: Int
        let label: String?
        let isEndpoint: Bool
    }

    private func tickMarks() -> [TickMark] {
        guard let fineDrag else {
            return stride(from: 0, through: TimeRangeSelection.dayMinutes, by: 180)
                .map { minutes in
                    TickMark(
                        minutes: minutes,
                        label: minutes.isMultiple(of: 360) ? String(minutes / 60) : nil,
                        isEndpoint: minutes == 0 || minutes == TimeRangeSelection.dayMinutes
                    )
                }
        }
        let first = Int(fineDrag.windowStart)
        let last = Int(fineDrag.windowEnd)
        return stride(from: first, through: last, by: 5)
            .map { minutes in
                let isEndpoint = minutes == first || minutes == last
                let label: String?
                if isEndpoint {
                    label = "\(minutes / 60)時"
                } else if minutes.isMultiple(of: 10) {
                    label = String(format: "%02d", minutes % 60)
                } else {
                    label = nil
                }
                return TickMark(minutes: minutes, label: label, isEndpoint: isEndpoint)
            }
    }

    private func labelRect(_ label: String, atX x: CGFloat) -> NSRect {
        let attributes: [NSAttributedString.Key: Any] = [.font: tickFont]
        let size = (label as NSString).size(withAttributes: attributes)
        return NSRect(
            x: x - size.width / 2,
            y: railRect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func drawTickLabel(_ label: String, atX x: CGFloat, isEndpoint: Bool) {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: tickFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.82)
        ]
        if isEndpoint {
            attributes[.strokeColor] = panelBackgroundColor
            attributes[.strokeWidth] = -3
        }
        let rect = labelRect(label, atX: x)
        (label as NSString).draw(at: rect.origin, withAttributes: attributes)
    }

    private func strokeVertical(
        x: CGFloat,
        from start: CGFloat,
        to end: CGFloat,
        color: NSColor,
        width: CGFloat = 1
    ) {
        guard end > start else { return }
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: start))
        path.line(to: NSPoint(x: x, y: end))
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    private func drawCentered(
        _ value: String,
        at location: NSPoint,
        font: NSFont,
        color: NSColor
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = (value as NSString).size(withAttributes: attributes)
        (value as NSString).draw(
            at: NSPoint(x: location.x - size.width / 2, y: location.y - size.height / 2),
            withAttributes: attributes
        )
    }

    // MARK: Accessibility

    override func isAccessibilityElement() -> Bool { false }

    override func accessibilityChildren() -> [Any]? {
        var children: [Any] = [previewElement]
        if showsKnob(.upper) { children.append(upperKnobElement) }
        if showsKnob(.lower) { children.append(lowerKnobElement) }
        return children
    }

    private func updateAccessibility() {
        previewElement.setAccessibilityValue(previewText)
        previewElement.setAccessibilityFrameInParentSpace(previewRect)
        for (element, handle) in [
            (upperKnobElement, Handle.upper),
            (lowerKnobElement, .lower)
        ] {
            let role = state.role(of: handle)
            let label: String
            if state.mode == .time {
                label = handle == .upper
                    ? "時刻のつまみ"
                    : "終了時刻のつまみ。値を変えると時間帯を選択"
            } else {
                label = role == .start ? "開始時刻のつまみ" : "終了時刻のつまみ"
            }
            let center = knobCenter(for: handle)
            element.setAccessibilityLabel(label)
            element.setAccessibilityValue(
                TimeRangeSelection.text(forMinutes: state.minutes(of: handle))
            )
            element.setAccessibilityFrameInParentSpace(NSRect(
                x: center.x - knobHitRadius,
                y: center.y - knobHitRadius,
                width: knobHitRadius * 2,
                height: knobHitRadius * 2
            ))
        }
    }
}
