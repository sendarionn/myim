@preconcurrency import AppKit
import MyIMECore

/// The start and end of a time range on one rail, shown in the time panel
/// in place of the clock; the two times above the rail are typed or follow
/// the knobs, and Return or ↵ inserts the range
final class TimeRangeView: NSView {
    typealias Edge = TimeRangeSelection.Edge

    static let height: CGFloat = 132

    var confirmAction: ((TimeRangeSelection) -> Void)?
    var cancelAction: (() -> Void)?
    var clockAction: (() -> Void)?

    private(set) var range = TimeRangeSelection(start: 0, end: 60)!
    private var focusedEdge: Edge = .start
    /// What was typed into the focused field; nil while it shows its value,
    /// which the first typed character replaces
    private var editingText: String?
    private var showsInvalidText = false
    private var draggingEdge: Edge?
    /// Set once the held knob has stayed still; the rail then shows an hour
    private var fineDrag: TimeRangeFineDrag?
    private var stillnessTimer: Timer?
    /// Where the cursor last moved more than the tolerance, and when
    private var stillOrigin: NSPoint = .zero
    private var stillSince: TimeInterval = 0
    private var lastDragPoint: NSPoint = .zero
    private static let stillDuration: TimeInterval = 0.4
    private static let stillTolerance: CGFloat = 3

    private let confirmButton = NSButton(title: "↵", target: nil, action: nil)
    private let clockButton = NSButton(title: "", target: nil, action: nil)
    private let startFieldElement = NSAccessibilityElement()
    private let endFieldElement = NSAccessibilityElement()
    private let startKnobElement = NSAccessibilityElement()
    private let endKnobElement = NSAccessibilityElement()

    private let railY: CGFloat = 56
    private let knobOffset: CGFloat = 13
    private let knobRadius: CGFloat = 7
    /// Each knob is taken from its own side of the rail, so both can be
    /// grabbed however close they are
    private let knobAreaHeight: CGFloat = 26
    private let fieldFont = NSFont.monospacedDigitSystemFont(
        ofSize: 20,
        weight: .semibold
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        confirmButton.isBordered = false
        confirmButton.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        confirmButton.contentTintColor = .controlAccentColor
        confirmButton.refusesFirstResponder = true
        confirmButton.target = self
        confirmButton.action = #selector(confirmClicked)
        confirmButton.setAccessibilityLabel("挿入")
        addSubview(confirmButton)

        clockButton.isBordered = false
        clockButton.image = NSImage(
            systemSymbolName: "clock",
            accessibilityDescription: "時計"
        )
        clockButton.contentTintColor = .secondaryLabelColor
        clockButton.refusesFirstResponder = true
        clockButton.target = self
        clockButton.action = #selector(clockClicked)
        clockButton.setAccessibilityLabel("時計")
        addSubview(clockButton)

        for (element, label) in [
            (startFieldElement, "開始時刻"),
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

    func begin(with range: TimeRangeSelection) {
        self.range = range
        focusedEdge = .start
        editingText = nil
        showsInvalidText = false
        endDrag()
        updateAccessibility()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        clockButton.frame = NSRect(x: 12, y: 87, width: 30, height: 30)
        confirmButton.frame = NSRect(
            x: bounds.width - 46,
            y: 87,
            width: 32,
            height: 30
        )
        updateAccessibility()
    }

    // MARK: Keys

    /// Every key reaching the panel ends here, whether the panel or the
    /// input method received it, so none goes on to the application
    func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 53:
            cancelAction?()
        case 36, 76:
            confirm()
        case 48:
            // Two fields, so Tab and Shift+Tab both go to the other one
            guard commitEditing() else { return }
            focusedEdge = focusedEdge == .start ? .end : .start
            needsDisplay = true
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

    override func keyDown(with event: NSEvent) {
        handleKey(event)
    }

    override func cancelOperation(_ sender: Any?) {
        cancelAction?()
    }

    private func edit(_ text: String) {
        editingText = text
        showsInvalidText = false
        // A time that is complete and in order moves the rail at once
        range.set(focusedEdge, text: text)
        updateAccessibility()
        needsDisplay = true
    }

    /// Keeps what was typed when it is a time in order with the other end;
    /// otherwise stays in the field to be corrected
    private func commitEditing() -> Bool {
        guard let editingText else { return true }
        guard range.set(focusedEdge, text: editingText) else {
            showsInvalidText = true
            needsDisplay = true
            NSSound.beep()
            return false
        }
        self.editingText = nil
        showsInvalidText = false
        needsDisplay = true
        return true
    }

    private func confirm() {
        guard commitEditing() else { return }
        confirmAction?(range)
    }

    @objc private func confirmClicked() {
        confirm()
    }

    @objc private func clockClicked() {
        clockAction?()
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
        drag(to: point)
        startStillnessTracking(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard draggingEdge != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        lastDragPoint = point
        if fineDrag != nil {
            dragFinely(to: point)
            return
        }
        drag(to: point)
        // Small shakes do not restart the wait
        if hypot(point.x - stillOrigin.x, point.y - stillOrigin.y)
            > Self.stillTolerance {
            stillOrigin = point
            stillSince = ProcessInfo.processInfo.systemUptime
        }
    }

    override func mouseUp(with event: NSEvent) {
        endDrag()
    }

    /// Ends a drag however it stops; the times stay as they were moved, and
    /// the rail shows the whole day again
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

    /// Checked on a timer, so holding the cursor still with no events also
    /// switches to the hour
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
        guard let draggingEdge, fineDrag == nil else {
            stillnessTimer?.invalidate()
            stillnessTimer = nil
            return
        }
        guard ProcessInfo.processInfo.systemUptime - stillSince
            >= Self.stillDuration else { return }
        stillnessTimer?.invalidate()
        stillnessTimer = nil
        // The knob keeps its place and time; the cursor from here on moves
        // it by the minute
        fineDrag = TimeRangeFineDrag(
            edge: draggingEdge,
            range: range,
            knobFraction: Double(range.minutes(of: draggingEdge))
                / Double(TimeRangeSelection.dayMinutes),
            cursorX: Double(lastDragPoint.x),
            railWidth: Double(railRect.width)
        )
        updateAccessibility()
        needsDisplay = true
    }

    private func dragFinely(to point: NSPoint) {
        guard var fineDrag else { return }
        fineDrag.drag(toX: Double(point.x), range: &range)
        self.fineDrag = fineDrag
        updateAccessibility()
        needsDisplay = true
    }

    private func drag(to point: NSPoint) {
        guard let draggingEdge else { return }
        let rail = railRect
        range.drag(
            draggingEdge,
            toFraction: Double((point.x - rail.minX) / rail.width)
        )
        updateAccessibility()
        needsDisplay = true
    }

    private func discardEditing() {
        editingText = nil
        showsInvalidText = false
    }

    private func fieldEdge(at point: NSPoint) -> Edge? {
        if fieldRect(for: .start).contains(point) { return .start }
        if fieldRect(for: .end).contains(point) { return .end }
        return nil
    }

    private func knobEdge(at point: NSPoint) -> Edge? {
        let rail = railRect
        guard point.x >= rail.minX - knobRadius * 2,
              point.x <= rail.maxX + knobRadius * 2 else { return nil }
        if point.y >= railY, point.y <= railY + knobAreaHeight { return .start }
        if point.y < railY, point.y >= railY - knobAreaHeight { return .end }
        return nil
    }

    // MARK: Geometry

    private var railRect: NSRect {
        NSRect(x: 28, y: railY - 2, width: bounds.width - 56, height: 4)
    }

    private func fieldRect(for edge: Edge) -> NSRect {
        let width: CGFloat = 92
        let x = edge == .start
            ? bounds.midX - 14 - width
            : bounds.midX + 14
        return NSRect(x: x, y: 87, width: width, height: 30)
    }

    /// On the whole day, or on the hour shown while a knob is held still
    private func x(forMinutes minutes: Int) -> CGFloat {
        let rail = railRect
        let fraction = fineDrag?.fraction(forMinutes: Double(minutes))
            ?? Double(minutes) / Double(TimeRangeSelection.dayMinutes)
        return rail.minX + rail.width * CGFloat(fraction)
    }

    /// The other knob is drawn only while its time is on the hour shown
    private func showsKnob(_ edge: Edge) -> Bool {
        guard let fineDrag, fineDrag.edge != edge else { return true }
        return fineDrag.contains(minutes: range.minutes(of: edge))
    }

    private func knobCenter(for edge: Edge) -> NSPoint {
        NSPoint(
            x: x(forMinutes: range.minutes(of: edge)),
            y: edge == .start ? railY + knobOffset : railY - knobOffset
        )
    }

    // MARK: Drawing

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
        drawCentered(
            "〜",
            at: NSPoint(x: bounds.midX, y: fieldRect(for: .start).midY),
            font: fieldFont,
            color: .secondaryLabelColor
        )
        drawField(.end)
        drawRail()
    }

    private func fieldText(for edge: Edge) -> String {
        if edge == focusedEdge, let editingText { return editingText }
        return TimeRangeSelection.text(forMinutes: range.minutes(of: edge))
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
            .foregroundColor: focused && showsInvalidText
                ? NSColor.systemRed
                : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = NSPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        // The value shown before typing is replaced by the first character
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
        let dayStartX = max(x(forMinutes: 0), rail.minX)
        let dayEndX = min(x(forMinutes: TimeRangeSelection.dayMinutes), rail.maxX)
        // Times outside the day cannot be chosen and are drawn faint
        NSColor.separatorColor.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: rail, xRadius: 2, yRadius: 2).fill()
        NSColor.separatorColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: dayStartX,
                y: rail.minY,
                width: max(dayEndX - dayStartX, 0),
                height: rail.height
            ),
            xRadius: 2,
            yRadius: 2
        ).fill()

        let startX = min(max(x(forMinutes: range.start), rail.minX), rail.maxX)
        let endX = min(max(x(forMinutes: range.end), rail.minX), rail.maxX)
        if endX > startX || fineDrag == nil {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(
                roundedRect: NSRect(
                    x: startX,
                    y: rail.minY,
                    width: max(endX - startX, fineDrag == nil ? 2 : 0),
                    height: rail.height
                ),
                xRadius: 2,
                yRadius: 2
            ).fill()
        }

        for (minutes, label) in tickMarks() {
            let tickX = x(forMinutes: minutes)
            NSColor.tertiaryLabelColor.setFill()
            NSRect(x: tickX - 0.5, y: rail.minY - 4, width: 1, height: 3).fill()
            drawCentered(
                label,
                at: NSPoint(x: tickX, y: 18),
                font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                color: .secondaryLabelColor
            )
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
            NSColor.controlAccentColor.setFill()
            knob.fill()
            if edge == focusedEdge {
                NSColor.labelColor.setStroke()
                knob.lineWidth = 1.5
                knob.stroke()
            }
        }
    }

    /// Every six hours on the whole day, every ten minutes on the hour
    /// shown; none outside the day
    private func tickMarks() -> [(minutes: Int, label: String)] {
        guard let fineDrag else {
            return stride(from: 0, through: 24, by: 6).map {
                ($0 * 60, String($0))
            }
        }
        let first = Int((fineDrag.windowStart / 10).rounded(.up)) * 10
        return stride(from: first, through: Int(fineDrag.windowEnd), by: 10)
            .filter { (0...TimeRangeSelection.dayMinutes).contains($0) }
            .map { ($0, TimeRangeSelection.text(forMinutes: $0)) }
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
            at: NSPoint(
                x: location.x - size.width / 2,
                y: location.y - size.height / 2
            ),
            withAttributes: attributes
        )
    }

    // MARK: Accessibility

    override func isAccessibilityElement() -> Bool { false }

    override func accessibilityChildren() -> [Any]? {
        [
            clockButton,
            startFieldElement,
            endFieldElement,
            confirmButton,
            startKnobElement,
            endKnobElement
        ]
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
            element.setAccessibilityValue(
                TimeRangeSelection.text(forMinutes: range.minutes(of: edge))
            )
            element.setAccessibilityFrameInParentSpace(NSRect(
                x: center.x - knobRadius,
                y: center.y - knobRadius,
                width: knobRadius * 2,
                height: knobRadius * 2
            ))
        }
    }
}
