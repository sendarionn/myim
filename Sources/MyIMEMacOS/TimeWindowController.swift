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

/// Twelve hour labels on one ring, switched between the AM and PM pages;
/// a label click selects the hour and the minute hand is dragged, while
/// the hour hand only shows the time
private final class AnalogClockView: NSView {
    var state: TimeSelectionState? { didSet { needsDisplay = true } }
    var page = TimeDialPage.am { didSet { needsDisplay = true } }
    var hourSelectionAction: ((Int) -> Void)?
    var minuteSelectionAction: ((Double) -> Void)?
    let layout = TimeDialLayout()

    private var isDraggingMinuteHand = false
    private var hoveredStep: Int? {
        didSet { if oldValue != hoveredStep { needsDisplay = true } }
    }

    override var isFlipped: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [
                .mouseMoved, .mouseEnteredAndExited,
                .activeAlways, .inVisibleRect
            ],
            owner: self
        ))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let state else { return }
        let center = dialCenter

        // The labels mark the hours, so neither ticks nor an outline are drawn
        for step in 0..<12 {
            drawLabel(
                page.label(atDialStep: step),
                at: labelPoint(step: step, center: center),
                selected: state.hour == page.hour(atDialStep: step),
                hovered: hoveredStep == step
            )
        }

        drawHand(
            from: center,
            angleDegrees: state.hourHandAngle,
            length: CGFloat(layout.hourHandLength),
            width: 3
        )
        drawHand(
            from: center,
            angleDegrees: state.minuteHandAngle,
            length: CGFloat(layout.minuteHandLength),
            width: 1.5
        )
        NSColor.labelColor.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: center.x - 3,
            y: center.y - 3,
            width: 6,
            height: 6
        )).fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard let state else { return }
        let offset = offsetFromCenter(of: event)
        if let step = layout.labelStep(atX: offset.x, y: offset.y) {
            hourSelectionAction?(step)
            return
        }
        // Grabbing does not move the hand; only dragging changes the minute
        isDraggingMinuteHand = layout.grabsMinuteHand(
            atX: offset.x,
            y: offset.y,
            state: state
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingMinuteHand else { return }
        let offset = offsetFromCenter(of: event)
        var angle = atan2(offset.x, offset.y) * 180 / .pi
        if angle < 0 { angle += 360 }
        minuteSelectionAction?(angle)
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingMinuteHand = false
    }

    override func mouseMoved(with event: NSEvent) {
        let offset = offsetFromCenter(of: event)
        hoveredStep = layout.labelStep(atX: offset.x, y: offset.y)
    }

    override func mouseExited(with event: NSEvent) {
        hoveredStep = nil
    }

    private var dialCenter: NSPoint {
        NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func offsetFromCenter(of event: NSEvent) -> (x: Double, y: Double) {
        let location = convert(event.locationInWindow, from: nil)
        let center = dialCenter
        return (Double(location.x - center.x), Double(location.y - center.y))
    }

    private func labelPoint(step: Int, center: NSPoint) -> NSPoint {
        let offset = layout.labelCenter(atDialStep: step)
        return NSPoint(
            x: center.x + CGFloat(offset.x),
            y: center.y + CGFloat(offset.y)
        )
    }

    private func drawLabel(
        _ value: String,
        at location: NSPoint,
        selected: Bool,
        hovered: Bool
    ) {
        let highlight = CGFloat(layout.labelHitRadius)
        let area = NSRect(
            x: location.x - highlight,
            y: location.y - highlight,
            width: highlight * 2,
            height: highlight * 2
        )
        if selected {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(ovalIn: area).fill()
        } else if hovered {
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(ovalIn: area).fill()
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(
                ofSize: CGFloat(layout.labelFontSize),
                weight: .regular
            ),
            .foregroundColor: selected
                ? NSColor.alternateSelectedControlTextColor
                : NSColor.labelColor
        ]
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

    private func drawHand(
        from center: NSPoint,
        angleDegrees: Double,
        length: CGFloat,
        width: CGFloat
    ) {
        let radians = CGFloat(angleDegrees) * .pi / 180
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: NSPoint(
            x: center.x + sin(radians) * length,
            y: center.y + cos(radians) * length
        ))
        path.lineWidth = width
        path.lineCapStyle = .round
        NSColor.labelColor.setStroke()
        path.stroke()
    }
}

private final class TimeInputView: NSView, NSTextFieldDelegate {
    var confirmAction: ((TimeSelectionState) -> Void)?
    var cancelAction: (() -> Void)?

    private let hourField = NSTextField()
    private let minuteField = NSTextField()
    private let separatorLabel = NSTextField(labelWithString: ":")
    private let clockView = AnalogClockView()
    /// Switches the labels between 1 to 12 and 13 to 24 without changing
    /// the time
    private let pageControl = NSSegmentedControl(
        labels: ["AM", "PM"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let errorLabel = NSTextField(labelWithString: "")
    private var state = TimeSelectionState(hour: 0, minute: 0)!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for field in [hourField, minuteField] {
            field.alignment = .center
            field.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
            field.focusRingType = .default
            field.delegate = self
            field.target = self
            field.action = #selector(confirm)
            addSubview(field)
        }
        separatorLabel.alignment = .center
        separatorLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        addSubview(separatorLabel)

        errorLabel.alignment = .center
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.textColor = .systemRed
        addSubview(errorLabel)

        clockView.hourSelectionAction = { [weak self] step in
            guard let self else { return }
            state.selectHour(atDialStep: step, page: clockView.page)
            syncControls()
        }
        pageControl.target = self
        pageControl.action = #selector(changePage)
        // Typing keeps going to the digit fields after a click on the switch
        pageControl.refusesFirstResponder = true
        addSubview(pageControl)
        clockView.minuteSelectionAction = { [weak self] angle in
            self?.state.selectMinute(atClockAngle: angle)
            self?.syncControls()
        }
        addSubview(clockView)

        hourField.nextKeyView = minuteField
        minuteField.nextKeyView = hourField
    }

    required init?(coder: NSCoder) { nil }

    func setInitialTime(_ date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        setTime(TimeSelectionState(hour: hour, minute: minute)!)
    }

    /// `keepsPage` keeps the AM or PM labels shown before, as when going
    /// back from the formats; otherwise the page showing the hour is used
    func setTime(_ time: TimeSelectionState, keepsPage: Bool = false) {
        state = time
        if !keepsPage {
            showPage(TimeDialPage(hour: time.hour))
        }
        syncControls()
    }

    @objc private func changePage() {
        showPage(pageControl.selectedSegment == 1 ? .pm : .am)
    }

    private func showPage(_ page: TimeDialPage) {
        clockView.page = page
        pageControl.selectedSegment = page == .am ? 0 : 1
    }

    func focusInitialField() {
        window?.makeFirstResponder(hourField)
        hourField.selectText(nil)
    }

    override func layout() {
        super.layout()
        let fieldWidth: CGFloat = 58
        let fieldHeight: CGFloat = 36
        let centerX = bounds.midX
        let top = bounds.height - 12 - fieldHeight
        hourField.frame = NSRect(
            x: centerX - 70, y: top, width: fieldWidth, height: fieldHeight
        )
        separatorLabel.frame = NSRect(
            x: centerX - 12, y: top, width: 24, height: fieldHeight
        )
        minuteField.frame = NSRect(
            x: centerX + 12, y: top, width: fieldWidth, height: fieldHeight
        )
        let diameter = CGFloat(clockView.layout.dialRadius * 2)
        clockView.frame = NSRect(
            x: centerX - diameter / 2,
            y: 28,
            width: diameter,
            height: diameter
        )
        pageControl.sizeToFit()
        pageControl.frame.origin = NSPoint(
            x: centerX - pageControl.frame.width / 2,
            y: clockView.frame.maxY + 10
        )
        errorLabel.frame = NSRect(x: 8, y: 5, width: bounds.width - 16, height: 18)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            confirm()
        case 53:
            cancelAction?()
        default:
            super.keyDown(with: event)
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        applyDraftsIfValid()
    }

    @objc private func confirm() {
        guard applyDraftsIfValid() else {
            NSSound.beep()
            return
        }
        confirmAction?(state)
    }

    @discardableResult
    private func applyDraftsIfValid() -> Bool {
        guard let hour = Int(hourField.stringValue),
              let minute = Int(minuteField.stringValue),
              TimeSelectionState.isValid(hour: hour, minute: minute) else {
            errorLabel.stringValue = "時は0〜23、分は0〜59で入力"
            return false
        }
        if hour != state.hour {
            showPage(TimeDialPage(hour: hour))
        }
        _ = state.set(hour: hour)
        _ = state.set(minute: minute)
        errorLabel.stringValue = ""
        clockView.state = state
        return true
    }

    private func syncControls() {
        hourField.stringValue = String(format: "%02d", state.hour)
        minuteField.stringValue = String(format: "%02d", state.minute)
        errorLabel.stringValue = ""
        clockView.state = state
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
        // The dial plus side margins, the AM and PM switch and the digit
        // fields above, and the error line below
        let diameter = CGFloat(TimeDialLayout().dialRadius * 2)
        let size = NSSize(width: diameter + 32, height: diameter + 126)
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
        (panel.firstResponder ?? inputView).keyDown(with: event)
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
            inputView.setTime(initialTime, keepsPage: true)
        } else {
            inputView.setInitialTime(initialDate)
        }
        position(near: anchorFrame)
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        panel.makeKeyAndOrderFront(nil)
        inputView.focusInitialField()
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
        guard panel.isVisible, !panel.frame.contains(point) else { return }
        cancelSelection()
    }
}
