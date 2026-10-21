@preconcurrency import AppKit
import MyIMECore

private final class TimePanel: NSPanel {
    var cancelAction: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        cancelAction?()
    }
}

/// The 24 hour labels on two rings around the minute ring and the HH:MM
/// display; a click on a label selects the hour and a press on the minute
/// ring sets the minute, both measured from the view's centre
private final class TimeDialView: NSView {
    var state: TimeSelectionState? { didSet { needsDisplay = true } }
    var hourSelectionAction: ((Int) -> Void)?
    var minuteSelectionAction: ((Int) -> Void)?
    let layout = TimeDialLayout()

    private var gesture: TimeDialPointerGesture?

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let state else { return }
        let center = dialCenter

        drawTimeDisplay(state.digitalText, at: center)
        // The labels mark the hours; no ticks, hands, or outline are drawn.
        // The ring holding the selected hour is darker, and both stay
        // clickable
        let selectedRing = TimeHourRing(hour: state.hour)
        for ring in TimeHourRing.allCases {
            for step in 0..<12 {
                let offset = layout.labelCenter(atDialStep: step, ring: ring)
                drawLabel(
                    ring.label(atDialStep: step),
                    at: NSPoint(
                        x: center.x + CGFloat(offset.x),
                        y: center.y + CGFloat(offset.y)
                    ),
                    selected: state.hour == ring.hour(atDialStep: step),
                    color: ring == selectedRing
                        ? .labelColor
                        : .secondaryLabelColor
                )
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let offset = offsetFromCenter(of: event)
        let pressed = TimeDialPointerGesture(
            atX: offset.x,
            y: offset.y,
            layout: layout
        )
        gesture = pressed
        if let minute = pressed.minuteOnPress(
            atX: offset.x,
            y: offset.y,
            layout: layout
        ) {
            minuteSelectionAction?(minute)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let offset = offsetFromCenter(of: event)
        guard let minute = gesture?.move(
            toX: offset.x,
            y: offset.y,
            layout: layout
        ) else { return }
        minuteSelectionAction?(minute)
    }

    override func mouseUp(with event: NSEvent) {
        defer { gesture = nil }
        let offset = offsetFromCenter(of: event)
        if case let .selectHour(hour) = gesture?.release(
            atX: offset.x,
            y: offset.y,
            layout: layout
        ) {
            hourSelectionAction?(hour)
        }
    }

    private var dialCenter: NSPoint {
        NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func offsetFromCenter(of event: NSEvent) -> (x: Double, y: Double) {
        let location = convert(event.locationInWindow, from: nil)
        let center = dialCenter
        return (Double(location.x - center.x), Double(location.y - center.y))
    }

    /// HH:MM is only shown; it takes no focus, cursor, or typing
    private func drawTimeDisplay(_ value: String, at center: NSPoint) {
        drawCentered(value, at: center, attributes: [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: CGFloat(layout.timeDisplayFontSize),
                weight: .medium
            ),
            .foregroundColor: NSColor.labelColor
        ])
    }

    private func drawLabel(
        _ value: String,
        at location: NSPoint,
        selected: Bool,
        color: NSColor
    ) {
        if selected {
            // One circle size for one and two digits, drawn over the
            // ring's shade
            let radius = CGFloat(layout.highlightRadius)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: location.x - radius,
                y: location.y - radius,
                width: radius * 2,
                height: radius * 2
            )).fill()
        }
        drawCentered(value, at: location, attributes: [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: CGFloat(layout.labelFontSize),
                weight: .regular
            ),
            .foregroundColor: selected ? NSColor.white : color
        ])
    }

    private func drawCentered(
        _ value: String,
        at location: NSPoint,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let text = value as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: location.x - size.width / 2,
                y: location.y - size.height / 2
            ),
            withAttributes: attributes
        )
    }
}

/// The round panel: the dial and HH:MM are only clicked and shown, and
/// the keyboard confirms with Enter or cancels with Esc
private final class TimeInputView: NSView {
    var confirmAction: ((TimeSelectionState) -> Void)?
    var cancelAction: (() -> Void)?

    private let dialView = TimeDialView()
    private var state = TimeSelectionState(hour: 0, minute: 0)!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        dialView.hourSelectionAction = { [weak self] hour in
            guard let self else { return }
            state.selectHour(hour)
            dialView.state = state
        }
        dialView.minuteSelectionAction = { [weak self] minute in
            guard let self else { return }
            _ = state.set(minute: minute)
            dialView.state = state
        }
        addSubview(dialView)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    func setInitialTime(_ date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        setTime(TimeSelectionState(hour: hour, minute: minute)!)
    }

    func setTime(_ time: TimeSelectionState) {
        state = time
        dialView.state = state
    }

    /// Takes the keys itself, since nothing in the panel is edited
    func takeKeyboard() {
        window?.makeFirstResponder(self)
    }

    /// The panel is the dial: a circle on a clear window
    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        NSColor.windowBackgroundColor.setFill()
        circle.fill()
        NSColor.separatorColor.setStroke()
        circle.lineWidth = 1
        circle.stroke()
    }

    override func layout() {
        super.layout()
        // The dial fills the panel, so both share one centre with HH:MM
        // and the minute angles
        dialView.frame = bounds
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            confirmAction?(state)
        case 53:
            cancelAction?()
        default:
            // Digits, Tab, and other keys change nothing
            break
        }
    }
}

private final class TimeFormatKeyPanel: NSPanel {
    var candidateCount = 0
    var selectedIndex: Int?
    var selectionChanged: ((Int?) -> Void)?
    var directionalSelection: ((Int?, CandidateNavigationDirection) -> Int?)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48:
            moveSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
        case 123, 124, 125, 126:
            let direction: CandidateNavigationDirection = switch event.keyCode {
            case 123: .left
            case 124: .right
            case 125: .down
            default: .up
            }
            moveSelection(direction)
        case 36, 76:
            if selectedIndex != nil { NSApp.stopModal(withCode: .OK) }
        case 53:
            NSApp.stopModal(withCode: .cancel)
        default:
            break
        }
    }

    private func moveSelection(by offset: Int) {
        guard candidateCount > 0 else { return }
        let current = selectedIndex ?? (offset > 0 ? -1 : 0)
        selectedIndex = (current + offset + candidateCount) % candidateCount
        selectionChanged?(selectedIndex)
    }

    private func moveSelection(_ direction: CandidateNavigationDirection) {
        guard candidateCount > 0 else { return }
        selectedIndex = selectedIndex == nil
            ? 0
            : directionalSelection?(selectedIndex, direction)
        selectionChanged?(selectedIndex)
    }
}

final class TimeWindowController: NSObject {
    private let panel: TimePanel
    private let inputView: TimeInputView
    private let formatKeyPanel: TimeFormatKeyPanel
    private var selectedTime: TimeSelectionState?
    private var outsideLocalMonitor: Any?
    private var outsideGlobalMonitor: Any?
    private var outsideClickTimer: Timer?

    override init() {
        // A square window just holding the round dial
        let diameter = CGFloat(TimeDialLayout().dialRadius * 2)
        let size = NSSize(width: diameter, height: diameter)
        inputView = TimeInputView(frame: NSRect(origin: .zero, size: size))
        panel = TimePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        formatKeyPanel = TimeFormatKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        for currentPanel in [panel, formatKeyPanel] {
            currentPanel.animationBehavior = .none
            currentPanel.level = .floating
            currentPanel.hidesOnDeactivate = false
            currentPanel.isReleasedWhenClosed = false
            currentPanel.becomesKeyOnlyIfNeeded = false
            currentPanel.collectionBehavior = [
                .moveToActiveSpace, .transient, .fullScreenAuxiliary
            ]
        }
        // Only the circle drawn by the input view shows
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView?.addSubview(inputView)
        inputView.autoresizingMask = [.width, .height]
        panel.cancelAction = { [weak self] in self?.cancelSelection() }
        inputView.cancelAction = { [weak self] in self?.cancelSelection() }
        inputView.confirmAction = { [weak self] state in self?.confirmSelection(state) }
        formatKeyPanel.alphaValue = 0.01
        formatKeyPanel.isOpaque = false
        formatKeyPanel.backgroundColor = .clear
        formatKeyPanel.level = .popUpMenu
    }

    var isVisible: Bool { panel.isVisible }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard panel.isVisible else { return false }
        if MyIMFeatureShortcut.time.shortcut.matches(event) {
            cancelSelection()
            return true
        }
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        if !modifiers.intersection([.command, .control, .option]).isEmpty {
            hide()
            return false
        }
        if event.keyCode == 53 {
            cancelSelection()
            return true
        }
        inputView.keyDown(with: event)
        return true
    }

    /// `initialTime` reopens the clock at a time chosen before; without it
    /// the clock starts at the current time
    func runSelection(
        near anchorFrame: NSRect,
        initialTime: TimeSelectionState? = nil,
        initialDate: Date = Date()
    ) -> TimeSelectionState? {
        selectedTime = nil
        if let initialTime {
            inputView.setTime(initialTime)
        } else {
            inputView.setInitialTime(initialDate)
        }
        position(near: anchorFrame)
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        panel.makeKeyAndOrderFront(nil)
        // The shadow follows the drawn circle rather than the square window
        panel.invalidateShadow()
        inputView.takeKeyboard()
        startOutsideClickMonitoring()
        let response = NSApp.runModal(for: panel)
        stopOutsideClickMonitoring()
        panel.orderOut(nil)
        if NSApp.activationPolicy() != previousPolicy {
            _ = NSApp.setActivationPolicy(previousPolicy)
        }
        return response == .OK ? selectedTime : nil
    }

    func runFormatSelection(
        candidateCount: Int,
        near anchorFrame: NSRect,
        directionalSelection: @escaping (Int?, CandidateNavigationDirection) -> Int?,
        selectionChanged: @escaping (Int?) -> Void
    ) -> TimeFormatSelectionOutcome {
        guard candidateCount > 0 else { return .closed }
        formatKeyPanel.candidateCount = candidateCount
        formatKeyPanel.selectedIndex = nil
        formatKeyPanel.directionalSelection = directionalSelection
        formatKeyPanel.selectionChanged = selectionChanged
        formatKeyPanel.setFrameOrigin(anchorFrame.origin)
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        formatKeyPanel.makeKeyAndOrderFront(nil)
        formatKeyPanel.makeFirstResponder(formatKeyPanel)
        let response = NSApp.runModal(for: formatKeyPanel)
        let result = formatKeyPanel.selectedIndex
        formatKeyPanel.orderOut(nil)
        formatKeyPanel.directionalSelection = nil
        formatKeyPanel.selectionChanged = nil
        if NSApp.activationPolicy() != previousPolicy {
            _ = NSApp.setActivationPolicy(previousPolicy)
        }
        switch response {
        case .OK:
            return result.map(TimeFormatSelectionOutcome.selected) ?? .closed
        case .cancel:
            return .returnToTime
        default:
            return .closed
        }
    }

    func hide() {
        stopOutsideClickMonitoring()
        if NSApp.modalWindow === panel || NSApp.modalWindow === formatKeyPanel {
            NSApp.abortModal()
        }
        panel.orderOut(nil)
        formatKeyPanel.orderOut(nil)
    }

    private func confirmSelection(_ state: TimeSelectionState) {
        selectedTime = state
        NSApp.stopModal(withCode: .OK)
    }

    private func cancelSelection() {
        selectedTime = nil
        if NSApp.modalWindow === panel { NSApp.stopModal(withCode: .cancel) }
        else { hide() }
    }

    private func position(near anchor: NSRect) {
        let resolved = anchor == .zero
            ? NSRect(origin: NSEvent.mouseLocation, size: NSSize(width: 1, height: 1))
            : anchor
        let screen = NSScreen.screens.first(where: {
            $0.frame.intersects(resolved)
        }) ?? NSScreen.main
        let visible = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let size = panel.frame.size
        let x = min(max(resolved.minX, visible.minX), visible.maxX - size.width)
        var y = resolved.minY - size.height - 6
        if y < visible.minY {
            y = min(resolved.maxY + 6, visible.maxY - size.height)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown
        ]
        outsideLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: mask
        ) { [weak self] event in
            self?.cancelIfOutside(NSEvent.mouseLocation)
            return event
        }
        outsideGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: mask
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cancelIfOutside(NSEvent.mouseLocation)
            }
        }
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            guard NSEvent.pressedMouseButtons != 0 else { return }
            self?.cancelIfOutside(NSEvent.mouseLocation)
        }
        outsideClickTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .modalPanel)
    }

    private func stopOutsideClickMonitoring() {
        if let monitor = outsideLocalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = outsideGlobalMonitor { NSEvent.removeMonitor(monitor) }
        outsideLocalMonitor = nil
        outsideGlobalMonitor = nil
        outsideClickTimer?.invalidate()
        outsideClickTimer = nil
    }

    private func cancelIfOutside(_ point: NSPoint) {
        let frame = panel.frame
        guard panel.isVisible,
              hypot(point.x - frame.midX, point.y - frame.midY)
                > frame.width / 2 else { return }
        cancelSelection()
    }
}
