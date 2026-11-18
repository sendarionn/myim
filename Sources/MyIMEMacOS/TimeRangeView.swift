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
        draggingEdge = nil
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
    }

    override func mouseDragged(with event: NSEvent) {
        guard draggingEdge != nil else { return }
        drag(to: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        draggingEdge = nil
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

    private func x(forMinutes minutes: Int) -> CGFloat {
        let rail = railRect
        return rail.minX
            + rail.width * CGFloat(minutes) / CGFloat(TimeRangeSelection.dayMinutes)
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
        NSColor.separatorColor.setFill()
        NSBezierPath(roundedRect: rail, xRadius: 2, yRadius: 2).fill()
        let startX = x(forMinutes: range.start)
        let endX = x(forMinutes: range.end)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(
            roundedRect: NSRect(
                x: startX,
                y: rail.minY,
                width: max(endX - startX, 2),
                height: rail.height
            ),
            xRadius: 2,
            yRadius: 2
        ).fill()

        for hour in stride(from: 0, through: 24, by: 6) {
            let tickX = x(forMinutes: hour * 60)
            NSColor.tertiaryLabelColor.setFill()
            NSRect(x: tickX - 0.5, y: rail.minY - 4, width: 1, height: 3).fill()
            drawCentered(
                String(hour),
                at: NSPoint(x: tickX, y: 18),
                font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                color: .secondaryLabelColor
            )
        }

        for edge in [Edge.start, .end] {
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
