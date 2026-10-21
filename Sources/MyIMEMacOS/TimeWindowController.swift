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

private final class AnalogClockView: NSView {
    var state: TimeSelectionState? { didSet { needsDisplay = true } }
    var selectionAction: ((Double) -> Void)?

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let state else { return }
        let inset: CGFloat = 8
        let dial = bounds.insetBy(dx: inset, dy: inset)
        let center = NSPoint(x: dial.midX, y: dial.midY)
        let radius = min(dial.width, dial.height) / 2

        NSColor.separatorColor.setStroke()
        let outline = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        outline.lineWidth = 1
        outline.stroke()

        for step in 0..<60 {
            let angle = CGFloat(step) * .pi / 30
            let outer = point(center: center, radius: radius - 2, angle: angle)
            let length: CGFloat = step.isMultiple(of: 5) ? 8 : 4
            let inner = point(
                center: center,
                radius: radius - 2 - length,
                angle: angle
            )
            let mark = NSBezierPath()
            mark.move(to: inner)
            mark.line(to: outer)
            mark.lineWidth = step.isMultiple(of: 5) ? 1.5 : 0.5
            mark.stroke()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor
        ]
        for value in 1...12 {
            let angle = CGFloat(value) * .pi / 6
            let location = point(center: center, radius: radius - 20, angle: angle)
            let text = String(value) as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(
                    x: location.x - size.width / 2,
                    y: location.y - size.height / 2
                ),
                withAttributes: attributes
            )
        }

        drawHand(
            from: center,
            angleDegrees: state.hourHandAngle,
            length: radius * 0.48,
            width: 3
        )
        drawHand(
            from: center,
            angleDegrees: state.minuteHandAngle,
            length: radius * 0.68,
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

    override func mouseDown(with event: NSEvent) { select(event) }
    override func mouseDragged(with event: NSEvent) { select(event) }

    private func select(_ event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        guard hypot(location.x - center.x, location.y - center.y) > 8 else { return }
        var angle = atan2(location.x - center.x, location.y - center.y) * 180 / .pi
        if angle < 0 { angle += 360 }
        selectionAction?(Double(angle))
    }

    private func point(center: NSPoint, radius: CGFloat, angle: CGFloat) -> NSPoint {
        NSPoint(
            x: center.x + sin(angle) * radius,
            y: center.y + cos(angle) * radius
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
        path.line(to: point(center: center, radius: length, angle: radians))
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
    private let periodControl = NSSegmentedControl(
        labels: ["午前", "午後"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let modeControl = NSSegmentedControl(
        labels: ["時", "分"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let clockView = AnalogClockView()
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

        periodControl.target = self
        periodControl.action = #selector(changePeriod)
        periodControl.segmentStyle = .texturedSquare
        addSubview(periodControl)

        modeControl.target = self
        modeControl.action = #selector(changeDialMode)
        modeControl.segmentStyle = .texturedSquare
        addSubview(modeControl)

        errorLabel.alignment = .center
        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.textColor = .systemRed
        addSubview(errorLabel)

        clockView.selectionAction = { [weak self] angle in
            self?.selectDial(at: angle)
        }
        addSubview(clockView)

        hourField.nextKeyView = minuteField
        minuteField.nextKeyView = hourField
    }

    required init?(coder: NSCoder) { nil }

    func setInitialTime(_ date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        state = TimeSelectionState(hour: hour, minute: minute)!
        state.dialComponent = .hour
        syncControls()
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
        periodControl.frame = NSRect(
            x: centerX - 70, y: top - 32, width: 140, height: 24
        )
        modeControl.frame = NSRect(
            x: centerX - 52, y: top - 62, width: 104, height: 24
        )
        clockView.frame = NSRect(x: centerX - 92, y: 28, width: 184, height: 184)
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

    func controlTextDidBeginEditing(_ notification: Notification) {
        if notification.object as? NSTextField === hourField {
            setMode(.hour)
        } else if notification.object as? NSTextField === minuteField {
            setMode(.minute)
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

    @objc private func changePeriod() {
        state.setPM(periodControl.selectedSegment == 1)
        syncControls()
    }

    @objc private func changeDialMode() {
        setMode(modeControl.selectedSegment == 0 ? .hour : .minute)
    }

    private func setMode(_ component: TimeDialComponent) {
        state.dialComponent = component
        modeControl.selectedSegment = component == .hour ? 0 : 1
        clockView.state = state
    }

    private func selectDial(at angle: Double) {
        if state.dialComponent == .hour {
            state.selectHour(atClockAngle: angle)
        } else {
            state.selectMinute(atClockAngle: angle)
        }
        syncControls()
    }

    @discardableResult
    private func applyDraftsIfValid() -> Bool {
        guard let hour = Int(hourField.stringValue),
              let minute = Int(minuteField.stringValue),
              TimeSelectionState.isValid(hour: hour, minute: minute) else {
            errorLabel.stringValue = "時は0〜23、分は0〜59で入力"
            return false
        }
        _ = state.set(hour: hour)
        _ = state.set(minute: minute)
        errorLabel.stringValue = ""
        periodControl.selectedSegment = state.isPM ? 1 : 0
        clockView.state = state
        return true
    }

    private func syncControls() {
        hourField.stringValue = String(format: "%02d", state.hour)
        minuteField.stringValue = String(format: "%02d", state.minute)
        periodControl.selectedSegment = state.isPM ? 1 : 0
        modeControl.selectedSegment = state.dialComponent == .hour ? 0 : 1
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
        let size = NSSize(width: 224, height: 330)
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

    func runSelection(
        near anchorFrame: NSRect,
        initialDate: Date = Date()
    ) -> TimeSelectionState? {
        selectedTime = nil
        inputView.setInitialTime(initialDate)
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
    ) -> Int? {
        guard candidateCount > 0 else { return nil }
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
        return response == .OK ? result : nil
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
