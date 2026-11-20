@preconcurrency import AppKit
import MyIMECore

/// A single 24-hour rail used for both a time and a time range
final class TimeRangeView: NSView {
    typealias Edge = TimeRangeSelection.Edge

    enum Mode: Equatable { case time, range }

    static let height: CGFloat = 132

    var timeAction: ((TimeSelectionState) -> Void)?
    var rangeAction: ((TimeRangeSelection) -> Void)?
    var cancelAction: (() -> Void)?

    private(set) var mode: Mode = .time
    private(set) var startMinutes = 0
    private(set) var endMinutes = 0
    private var focusedEdge: Edge = .start
    private var editingText: String?
    private var showsInvalidText = false
    private var draggingEdge: Edge?
    private var dragOriginX: CGFloat = 0
    private var dragOriginMinutes: Double = 0
    private var exactDragMinutes: Double = 0
    private var fineDrag: FineDrag?
    private var stillnessTimer: Timer?
    private var stillOrigin: NSPoint = .zero
    private var stillSince: TimeInterval = 0
    private var lastDragPoint: NSPoint = .zero
    private static let stillDuration: TimeInterval = 0.4
    private static let stillTolerance: CGFloat = 3
    private static let step = 5

    private struct FineDrag {
        let windowStart: Double
        let edge: Edge
        let railWidth: Double
        var lastX: Double
        var exactMinutes: Double

        var windowEnd: Double { windowStart + 60 }
        func fraction(for minutes: Double) -> Double { (minutes - windowStart) / 60 }
        func contains(_ minutes: Int) -> Bool {
            Double(minutes) >= windowStart && Double(minutes) <= windowEnd
        }
    }

    private let startFieldElement = NSAccessibilityElement()
    private let endFieldElement = NSAccessibilityElement()
    private let startKnobElement = NSAccessibilityElement()
    private let endKnobElement = NSAccessibilityElement()
    private let railY: CGFloat = 48
    private let knobOffset: CGFloat = 13
    private let knobRadius: CGFloat = 7
    private let knobHitRadius: CGFloat = 14
    private let fieldFont = NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .semibold)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for (element, label) in [
            (startFieldElement, "時刻"),
            (endFieldElement, "終了時刻")
        ] {
            element.setAccessibilityRole(.textField)
            element.setAccessibilityLabel(label)
            element.setAccessibilityParent(self)
        }
        for (element, label) in [
            (startKnobElement, "開始時刻のつまみ"),
            (endKnobElement, "終了時刻のつまみ")
        ] {
            element.setAccessibilityRole(.slider)
            element.setAccessibilityLabel(label)
            element.setAccessibilityParent(self)
        }
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    func begin(with time: TimeSelectionState) {
        let minutes = Self.roundedSelectableMinutes(time.hour * 60 + time.minute)
        mode = .time
        startMinutes = minutes
        endMinutes = minutes
        focusedEdge = .start
        resetInteraction()
    }

    func begin(with range: TimeRangeSelection) {
        mode = .range
        startMinutes = range.start
        endMinutes = range.end
        focusedEdge = .start
        resetInteraction()
    }

    @discardableResult
    func returnToTimeMode() -> Bool {
        guard mode == .range else { return false }
        endDrag()
        mode = .time
        endMinutes = startMinutes
        focusedEdge = .start
        editingText = nil
        showsInvalidText = false
        updateAccessibility()
        needsDisplay = true
        return true
    }

    private func resetInteraction() {
        editingText = nil
        showsInvalidText = false
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
            guard commitEditing() else { return }
            focusedEdge = focusedEdge == .start ? .end : .start
            needsDisplay = true
        case 123, 125:
            moveFocusedEdge(by: -Self.step)
        case 124, 126:
            moveFocusedEdge(by: Self.step)
        case 51, 117:
            var text = editingText ?? ""
            if !text.isEmpty { text.removeLast() }
            edit(text)
        default:
            guard let characters = event.characters,
                  characters.count == 1,
                  characters.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ":") })
            else { return }
            let text = (editingText ?? "") + characters
            guard text.count <= 5 else { return }
            edit(text)
        }
    }

    override func keyDown(with event: NSEvent) { handleKey(event) }
    override func cancelOperation(_ sender: Any?) { cancelAction?() }

    private func edit(_ text: String) {
        editingText = text
        showsInvalidText = false
        if focusedEdge == .end, mode == .time, !text.isEmpty {
            mode = .range
        }
        if let minutes = validMinutes(from: text, for: focusedEdge) {
            apply(minutes, to: focusedEdge, entersRange: focusedEdge == .end)
        }
        updateAccessibility()
        needsDisplay = true
    }

    private func commitEditing() -> Bool {
        guard let editingText else { return true }
        guard let minutes = validMinutes(from: editingText, for: focusedEdge) else {
            showsInvalidText = true
            needsDisplay = true
            NSSound.beep()
            return false
        }
        apply(minutes, to: focusedEdge, entersRange: focusedEdge == .end)
        self.editingText = nil
        showsInvalidText = false
        needsDisplay = true
        return true
    }

    private func validMinutes(from text: String, for edge: Edge) -> Int? {
        guard let minutes = TimeRangeSelection.minutes(from: text),
              minutes.isMultiple(of: Self.step) else { return nil }
        switch edge {
        case .start:
            guard minutes < TimeRangeSelection.dayMinutes,
                  mode == .time || minutes <= endMinutes else { return nil }
        case .end:
            guard minutes >= startMinutes else { return nil }
        }
        return minutes
    }

    private func moveFocusedEdge(by delta: Int) {
        guard commitEditing() else { return }
        let edge = focusedEdge
        let current = minutes(of: edge)
        let bounds = allowedMinutes(for: edge)
        let value = min(max(current + delta, bounds.lowerBound), bounds.upperBound)
        guard value != current else { return }
        apply(value, to: edge, entersRange: edge == .end)
        needsDisplay = true
        updateAccessibility()
    }

    private func confirm() {
        guard commitEditing() else { return }
        switch mode {
        case .time:
            guard let time = TimeSelectionState(
                hour: startMinutes / 60,
                minute: startMinutes % 60
            ) else { return }
            timeAction?(time)
        case .range:
            guard let range = TimeRangeSelection(start: startMinutes, end: endMinutes) else {
                NSSound.beep()
                return
            }
            rangeAction?(range)
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let edge = fieldEdge(at: point) {
            if edge != focusedEdge { discardEditing() }
            focusedEdge = edge
            needsDisplay = true
            return
        }
        guard let edge = knobEdge(at: point) else { return }
        discardEditing()
        focusedEdge = edge
        draggingEdge = edge
        dragOriginX = point.x
        dragOriginMinutes = Double(minutes(of: edge))
        exactDragMinutes = dragOriginMinutes
        startStillnessTracking(at: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let edge = draggingEdge else { return }
        let point = convert(event.locationInWindow, from: nil)
        lastDragPoint = point
        if fineDrag != nil {
            dragFinely(to: point)
        } else {
            let delta = Double(point.x - dragOriginX)
                * Double(TimeRangeSelection.dayMinutes) / Double(max(railRect.width, 1))
            exactDragMinutes = dragOriginMinutes + delta
            applyDragged(exactDragMinutes, to: edge)
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
        draggingEdge = nil
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
        guard let edge = draggingEdge, fineDrag == nil else {
            stillnessTimer?.invalidate()
            stillnessTimer = nil
            return
        }
        guard ProcessInfo.processInfo.systemUptime - stillSince >= Self.stillDuration else { return }
        stillnessTimer?.invalidate()
        stillnessTimer = nil
        let minutes = Double(self.minutes(of: edge))
        let fraction = minutes / Double(TimeRangeSelection.dayMinutes)
        let start = min(
            max(minutes - 60 * fraction, 0),
            Double(TimeRangeSelection.dayMinutes - 60)
        )
        fineDrag = FineDrag(
            windowStart: start,
            edge: edge,
            railWidth: Double(max(railRect.width, 1)),
            lastX: Double(lastDragPoint.x),
            exactMinutes: minutes
        )
        updateAccessibility()
        needsDisplay = true
    }

    private func dragFinely(to point: NSPoint) {
        guard var fineDrag else { return }
        let delta = (Double(point.x) - fineDrag.lastX) * 60 / fineDrag.railWidth
        fineDrag.lastX = Double(point.x)
        fineDrag.exactMinutes += delta
        let bounds = allowedMinutes(for: fineDrag.edge)
        fineDrag.exactMinutes = min(
            max(fineDrag.exactMinutes, Double(bounds.lowerBound)),
            Double(bounds.upperBound)
        )
        applyDragged(fineDrag.exactMinutes, to: fineDrag.edge)
        self.fineDrag = fineDrag
    }

    private func applyDragged(_ exactMinutes: Double, to edge: Edge) {
        let rounded = Int((exactMinutes / Double(Self.step)).rounded()) * Self.step
        let bounds = allowedMinutes(for: edge)
        let value = min(max(rounded, bounds.lowerBound), bounds.upperBound)
        guard value != minutes(of: edge) else { return }
        apply(value, to: edge, entersRange: edge == .end)
        updateAccessibility()
        needsDisplay = true
    }

    private func apply(_ minutes: Int, to edge: Edge, entersRange: Bool) {
        if entersRange, mode == .time { mode = .range }
        switch edge {
        case .start:
            startMinutes = minutes
            if mode == .time { endMinutes = minutes }
        case .end:
            endMinutes = minutes
        }
    }

    private func allowedMinutes(for edge: Edge) -> ClosedRange<Int> {
        switch edge {
        case .start:
            return 0...(mode == .time ? 1435 : min(endMinutes, 1435))
        case .end:
            return startMinutes...TimeRangeSelection.dayMinutes
        }
    }

    private func minutes(of edge: Edge) -> Int { edge == .start ? startMinutes : endMinutes }
    private func discardEditing() { editingText = nil; showsInvalidText = false }

    private func fieldEdge(at point: NSPoint) -> Edge? {
        if fieldRect(for: .start).contains(point) { return .start }
        if mode == .range, fieldRect(for: .end).contains(point) { return .end }
        return nil
    }

    private func knobEdge(at point: NSPoint) -> Edge? {
        for edge in [Edge.start, .end] where showsKnob(edge) {
            let center = knobCenter(for: edge)
            if hypot(point.x - center.x, point.y - center.y) <= knobHitRadius { return edge }
        }
        return nil
    }

    // MARK: Geometry and drawing

    private var railRect: NSRect {
        NSRect(x: 28, y: railY - 2, width: bounds.width - 56, height: 4)
    }

    private func fieldRect(for edge: Edge) -> NSRect {
        let width: CGFloat = 92
        if mode == .time {
            return NSRect(x: bounds.midX - width / 2, y: 88, width: width, height: 30)
        }
        let x = edge == .start ? bounds.midX - 14 - width : bounds.midX + 14
        return NSRect(x: x, y: 88, width: width, height: 30)
    }

    private func x(forMinutes minutes: Int) -> CGFloat {
        let rail = railRect
        let fraction = fineDrag?.fraction(for: Double(minutes))
            ?? Double(minutes) / Double(TimeRangeSelection.dayMinutes)
        return rail.minX + rail.width * CGFloat(fraction)
    }

    private func showsKnob(_ edge: Edge) -> Bool {
        guard let fineDrag, fineDrag.edge != edge else { return true }
        return fineDrag.contains(minutes(of: edge))
    }

    private func knobCenter(for edge: Edge) -> NSPoint {
        NSPoint(
            x: x(forMinutes: minutes(of: edge)),
            y: edge == .start ? railY + knobOffset : railY - knobOffset
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let background = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 14,
            yRadius: 14
        )
        NSColor.windowBackgroundColor.setFill()
        background.fill()
        NSColor.separatorColor.setStroke()
        background.lineWidth = 1
        background.stroke()

        drawField(.start)
        if mode == .range {
            drawCentered(
                "〜",
                at: NSPoint(x: bounds.midX, y: fieldRect(for: .start).midY),
                font: fieldFont,
                color: .secondaryLabelColor
            )
            drawField(.end)
        }
        drawRail()
    }

    private func fieldText(for edge: Edge) -> String {
        if edge == focusedEdge, let editingText { return editingText }
        return TimeRangeSelection.text(forMinutes: minutes(of: edge))
    }

    private func drawField(_ edge: Edge) {
        let rect = fieldRect(for: edge)
        let focused = edge == focusedEdge
        if focused {
            let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            path.fill()
        }
        let text = fieldText(for: edge)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: fieldFont,
            .foregroundColor: focused && showsInvalidText ? NSColor.systemRed : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        if focused, editingText == nil {
            NSColor.selectedTextBackgroundColor.setFill()
            NSRect(origin: origin, size: size).fill()
        }
        (text as NSString).draw(at: origin, withAttributes: attributes)
        if focused, editingText != nil {
            NSColor.labelColor.setFill()
            NSRect(
                x: origin.x + size.width + 1,
                y: origin.y + 2,
                width: 1.5,
                height: size.height - 4
            ).fill()
        }
    }

    private func drawRail() {
        let rail = railRect
        NSColor.separatorColor.setFill()
        NSBezierPath(roundedRect: rail, xRadius: 2, yRadius: 2).fill()
        if mode == .range, endMinutes > startMinutes {
            let startX = x(forMinutes: startMinutes)
            let endX = x(forMinutes: endMinutes)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(
                roundedRect: NSRect(
                    x: startX,
                    y: rail.minY,
                    width: max(endX - startX, 0),
                    height: rail.height
                ),
                xRadius: 2,
                yRadius: 2
            ).fill()
        }

        for tick in tickMarks() {
            let tickX = x(forMinutes: tick.minutes)
            NSColor.tertiaryLabelColor.setFill()
            NSRect(x: tickX - 0.5, y: rail.minY - 4, width: 1, height: 3).fill()
            if let label = tick.label {
                drawCentered(
                    label,
                    at: NSPoint(x: tickX, y: 15),
                    font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    color: .secondaryLabelColor
                )
            }
        }

        for edge in [Edge.start, .end] where showsKnob(edge) {
            let center = knobCenter(for: edge)
            let stem = NSBezierPath()
            stem.move(to: NSPoint(x: center.x, y: railY))
            stem.line(to: center)
            NSColor.controlAccentColor.setStroke()
            stem.lineWidth = 1.5
            stem.stroke()
            let knob = NSBezierPath(ovalIn: NSRect(
                x: center.x - knobRadius,
                y: center.y - knobRadius,
                width: knobRadius * 2,
                height: knobRadius * 2
            ))
            if mode == .time, edge == .end {
                NSColor.windowBackgroundColor.setFill()
                knob.fill()
                NSColor.controlAccentColor.setStroke()
                knob.lineWidth = 1.5
                knob.stroke()
            } else {
                NSColor.controlAccentColor.setFill()
                knob.fill()
                if edge == focusedEdge {
                    NSColor.labelColor.setStroke()
                    knob.lineWidth = 1.5
                    knob.stroke()
                }
            }
        }
    }

    private func tickMarks() -> [(minutes: Int, label: String?)] {
        guard let fineDrag else {
            return stride(from: 0, through: 24, by: 6).map { ($0 * 60, String($0)) }
        }
        let first = Int((fineDrag.windowStart / 5).rounded(.up)) * 5
        return stride(from: first, through: Int(fineDrag.windowEnd), by: 5)
            .filter { (0...TimeRangeSelection.dayMinutes).contains($0) }
            .map { minutes in
                (minutes, minutes.isMultiple(of: 10)
                    ? TimeRangeSelection.text(forMinutes: minutes)
                    : nil)
            }
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
        var children: [Any] = [startFieldElement]
        if mode == .range { children.append(endFieldElement) }
        children.append(contentsOf: [startKnobElement, endKnobElement])
        return children
    }

    private func updateAccessibility() {
        for (element, edge) in [
            (startFieldElement, Edge.start),
            (endFieldElement, .end)
        ] {
            element.setAccessibilityValue(fieldText(for: edge))
            element.setAccessibilityFrameInParentSpace(fieldRect(for: edge))
        }
        for (element, edge) in [
            (startKnobElement, Edge.start),
            (endKnobElement, .end)
        ] {
            let center = knobCenter(for: edge)
            element.setAccessibilityValue(TimeRangeSelection.text(forMinutes: minutes(of: edge)))
            element.setAccessibilityFrameInParentSpace(NSRect(
                x: center.x - knobHitRadius,
                y: center.y - knobHitRadius,
                width: knobHitRadius * 2,
                height: knobHitRadius * 2
            ))
        }
    }

    private static func roundedSelectableMinutes(_ minutes: Int) -> Int {
        min(max(Int((Double(minutes) / Double(step)).rounded()) * step, 0), 1435)
    }
}
