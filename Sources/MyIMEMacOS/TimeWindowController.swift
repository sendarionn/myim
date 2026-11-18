@preconcurrency import AppKit
import MyIMECore

private final class TimePanel: NSPanel {
    var cancelAction: (() -> Void)?
    var shortcutAction: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        cancelAction?()
    }

    /// The time shortcut pressed while the panel has the keys
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           MyIMFeatureShortcut.time.shortcut.matches(event) {
            shortcutAction?()
            return
        }
        super.sendEvent(event)
    }
}

/// One circle reused for period, hour, and minute selection
private final class TimeDialView: NSView {
    var flow: TimeInputFlow? { didSet { needsDisplay = true } }
    var selectionAction: ((TimeDialSelection) -> Void)?
    let layout = TimeDialLayout()
    private var pendingSelection: TimeDialSelection?

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let flow else { return }
        let center = dialCenter

        drawBackground(at: center)
        if flow.stage == .period {
            drawPeriodDivider(at: center)
            drawSelectedPeriodBorder(in: flow, at: center)
        } else {
            if flow.stage == .minute { drawMinuteTicks(at: center) }
            drawNeedle(in: flow, at: center)
        }
        let count = flow.stage == .period ? 2 : 12
        for step in 0..<count {
            let offset = layout.labelCenter(
                atDialStep: step,
                stage: flow.stage
            )
            let selection = selection(atDialStep: step, stage: flow.stage)
            drawLabel(
                layout.label(atDialStep: step, stage: flow.stage),
                at: NSPoint(
                    x: center.x + CGFloat(offset.x),
                    y: center.y + CGFloat(offset.y)
                ),
                selected: flow.stage == .period
                    ? false
                    : (pendingSelection.map { $0 == selection }
                        ?? isSelected(selection, in: flow)),
                stage: flow.stage
            )
            if flow.stage == .period {
                drawPeriodSubtitle(
                    step == 0 ? "午前" : "午後",
                    at: NSPoint(
                        x: center.x + CGFloat(offset.x),
                        y: center.y + CGFloat(offset.y) - 27
                    )
                )
            }
        }
        if flow.stage != .period { drawCenterDot(at: center) }
    }

    override func mouseDown(with event: NSEvent) {
        updatePendingSelection(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updatePendingSelection(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        updatePendingSelection(with: event)
        let selection = pendingSelection
        pendingSelection = nil
        needsDisplay = true
        if let selection { selectionAction?(selection) }
    }

    private func updatePendingSelection(with event: NSEvent) {
        guard let flow else { return }
        let offset = offsetFromCenter(of: event)
        pendingSelection = layout.selection(
            atX: offset.x,
            y: offset.y,
            stage: flow.stage
        )
        needsDisplay = true
    }

    private var dialCenter: NSPoint {
        NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private func offsetFromCenter(of event: NSEvent) -> (x: Double, y: Double) {
        let location = convert(event.locationInWindow, from: nil)
        let center = dialCenter
        return (Double(location.x - center.x), Double(location.y - center.y))
    }

    private func drawBackground(at center: NSPoint) {
        let radius = CGFloat(layout.outerRadius)
        NSColor.controlBackgroundColor.withAlphaComponent(0.72).setFill()
        NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )).fill()
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        path.lineWidth = 1
        path.stroke()
    }

    private func drawPeriodDivider(at center: NSPoint) {
        let radius = CGFloat(layout.outerRadius)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: center.x - radius, y: center.y))
        path.line(to: NSPoint(x: center.x + radius, y: center.y))
        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private func drawSelectedPeriodBorder(
        in flow: TimeInputFlow,
        at center: NSPoint
    ) {
        let period: TimePeriod
        if case let .period(value)? = pendingSelection {
            period = value
        } else {
            period = flow.time.period
        }
        let path = NSBezierPath()
        let angles: (CGFloat, CGFloat) = period == .am
            ? (0, 180)
            : (180, 360)
        path.appendArc(
            withCenter: center,
            radius: CGFloat(layout.outerRadius - 2),
            startAngle: angles.0,
            endAngle: angles.1
        )
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 3
        path.stroke()
    }

    private func drawMinuteTicks(at center: NSPoint) {
        for minute in 0..<60 {
            let angle = Double(minute) * .pi / 30
            let outer = CGFloat(layout.outerRadius - 4)
            let inner = outer - (minute.isMultiple(of: 5) ? 6 : 3)
            let start = NSPoint(
                x: center.x + CGFloat(sin(angle)) * inner,
                y: center.y + CGFloat(cos(angle)) * inner
            )
            let end = NSPoint(
                x: center.x + CGFloat(sin(angle)) * outer,
                y: center.y + CGFloat(cos(angle)) * outer
            )
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            NSColor.tertiaryLabelColor.setStroke()
            path.lineWidth = minute.isMultiple(of: 5) ? 1 : 0.5
            path.stroke()
        }
    }

    private func drawNeedle(in flow: TimeInputFlow, at center: NSPoint) {
        let selection = pendingSelection ?? selectedValue(in: flow)
        let step: Int = switch selection {
        case let .hour(hour): hour % 12
        case let .minute(minute): minute / 5
        case .period: 0
        }
        let offset = layout.labelCenter(atDialStep: step, stage: flow.stage)
        let scale = 1.0
        let end = NSPoint(
            x: center.x + CGFloat(offset.x * scale),
            y: center.y + CGFloat(offset.y * scale)
        )
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: end)
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.stroke()
    }

    private func drawCenterDot(at center: NSPoint) {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: NSRect(
            x: center.x - 4,
            y: center.y - 4,
            width: 8,
            height: 8
        )).fill()
    }

    private func selectedValue(in flow: TimeInputFlow) -> TimeDialSelection {
        switch flow.stage {
        case .period: .period(flow.time.period)
        case .hour: .hour(flow.time.twelveHour)
        case .minute: .minute(flow.time.minute)
        }
    }

    private func isSelected(
        _ selection: TimeDialSelection,
        in flow: TimeInputFlow
    ) -> Bool {
        switch selection {
        case let .period(period): flow.time.period == period
        case let .hour(hour): flow.time.twelveHour == hour
        case let .minute(minute): flow.time.minute == minute
        }
    }

    private func selection(
        atDialStep step: Int,
        stage: TimeInputStage
    ) -> TimeDialSelection {
        switch stage {
        case .period:
            .period(step == 0 ? .am : .pm)
        case .hour:
            .hour(step == 0 ? 12 : step)
        case .minute:
            .minute(step * 5)
        }
    }

    private func drawPeriodSubtitle(_ value: String, at center: NSPoint) {
        drawCentered(
            value,
            at: center,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
    }

    private func drawLabel(
        _ value: String,
        at location: NSPoint,
        selected: Bool,
        stage: TimeInputStage
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
                ofSize: CGFloat(
                    stage == .period
                        ? layout.periodFontSize
                        : layout.labelFontSize
                ),
                weight: .regular
            ),
            .foregroundColor: selected ? NSColor.white : NSColor.labelColor
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

/// Owns the staged AM/PM, hour, and minute flow
private final class TimeInputView: NSView {
    var confirmAction: ((TimeSelectionState) -> Void)?
    var cancelAction: (() -> Void)?

    private let dialView = TimeDialView()
    private var flow = TimeInputFlow(
        time: TimeSelectionState(hour: 0, minute: 0)!
    )
    private var arrowSequence = TimeDialArrowSequence()

    private let panelLayout = TimeDialLayout()
    private let footerHeight: CGFloat = 52
    private let dialOriginY: CGFloat = 58

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        dialView.selectionAction = { [weak self] selection in
            guard let self else { return }
            arrowSequence.reset()
            if let completed = flow.select(selection) {
                confirmAction?(completed)
            } else {
                dialView.flow = flow
                needsDisplay = true
            }
        }
        addSubview(dialView)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    /// The time the clock shows now, which a range starts from
    var currentTime: TimeSelectionState { flow.time }

    func setInitialTime(_ date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        setTime(
            TimeSelectionState(hour: hour, minute: minute)!
                .roundedToNearestFiveMinutes(),
            stage: .period
        )
    }

    func setTime(
        _ time: TimeSelectionState,
        stage: TimeInputStage = .period
    ) {
        arrowSequence.reset()
        flow = TimeInputFlow(time: time, stage: stage)
        dialView.flow = flow
        needsDisplay = true
    }

    /// Takes the keys itself, since nothing in the panel is edited
    func takeKeyboard() {
        window?.makeFirstResponder(self)
    }

    override func layout() {
        super.layout()
        let diameter = CGFloat(panelLayout.dialRadius * 2)
        dialView.frame = NSRect(
            x: (bounds.width - diameter) / 2,
            y: dialOriginY,
            width: diameter,
            height: diameter
        )
    }

    /// Returns false when Esc should close the whole time panel
    func moveBack() -> Bool {
        arrowSequence.reset()
        guard flow.moveBack() else { return false }
        dialView.flow = flow
        needsDisplay = true
        return true
    }

    func restart() {
        arrowSequence.reset()
        flow.restart()
        dialView.flow = flow
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawPanelBackground()
        drawStepIndicator()
        drawHeading()
        drawFooter()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if backRect.contains(point) {
            if !moveBack() { cancelAction?() }
            return
        }
        if restartRect.contains(point) {
            restart()
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 124, 125, 126:
            let direction: TimeDialArrowDirection = switch event.keyCode {
            case 123: .left
            case 124: .right
            case 125: .down
            default: .up
            }
            _ = flow.moveSelection(
                direction,
                sequence: &arrowSequence,
                at: event.timestamp
            )
            dialView.flow = flow
            needsDisplay = true
        case 36, 76:
            arrowSequence.reset()
            if let completed = flow.confirmCurrentSelection() {
                confirmAction?(completed)
            } else {
                dialView.flow = flow
                needsDisplay = true
            }
        case 53:
            if !moveBack() { cancelAction?() }
        default:
            break
        }
    }

    private func drawPanelBackground() {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private var displayedStep: Int {
        switch flow.stage {
        case .period: 0
        case .hour: 1
        case .minute: 2
        }
    }

    private func drawStepIndicator() {
        let labels = ["AM/PM", "時", "分", "候補"]
        let centers: [CGFloat] = [45, 126, 207, 287]
        let circleY = bounds.height - 22
        for index in 0..<centers.count - 1 {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: centers[index] + 11, y: circleY))
            line.line(to: NSPoint(x: centers[index + 1] - 11, y: circleY))
            (index < displayedStep
                ? NSColor.controlAccentColor
                : NSColor.separatorColor).setStroke()
            line.lineWidth = 1
            line.stroke()
        }
        for (index, x) in centers.enumerated() {
            let active = index == displayedStep
            let complete = index < displayedStep
            let rect = NSRect(x: x - 9, y: circleY - 9, width: 18, height: 18)
            let circle = NSBezierPath(ovalIn: rect)
            if active {
                NSColor.controlAccentColor.setFill()
                circle.fill()
            } else {
                (complete
                    ? NSColor.controlAccentColor
                    : NSColor.separatorColor).setStroke()
                circle.lineWidth = 1
                circle.stroke()
            }
            drawCentered(
                complete ? "✓" : String(index + 1),
                at: NSPoint(x: x, y: circleY),
                font: NSFont.systemFont(ofSize: 10, weight: .medium),
                color: active ? .white : (complete ? .controlAccentColor : .secondaryLabelColor)
            )
            drawCentered(
                labels[index],
                at: NSPoint(x: x, y: circleY - 18),
                font: NSFont.systemFont(ofSize: 11),
                color: active ? .labelColor : .secondaryLabelColor
            )
        }
    }

    private func drawHeading() {
        let heading = switch flow.stage {
        case .period: "午前・午後を選択"
        case .hour: "時を選択"
        case .minute: "分を選択"
        }
        drawCentered(
            heading,
            at: NSPoint(x: bounds.midX, y: bounds.height - 63),
            font: NSFont.systemFont(ofSize: 17, weight: .semibold),
            color: .labelColor
        )
    }

    private func drawFooter() {
        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: 14, y: footerHeight))
        separator.line(to: NSPoint(x: bounds.width - 14, y: footerHeight))
        NSColor.separatorColor.setStroke()
        separator.lineWidth = 0.5
        separator.stroke()
        drawText(
            "← 戻る（Esc）",
            in: backRect,
            alignment: .left,
            font: NSFont.systemFont(ofSize: 11),
            color: .secondaryLabelColor
        )
        drawCentered(
            flow.time.digitalText,
            at: NSPoint(x: bounds.midX, y: 25),
            font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium),
            color: .labelColor
        )
        drawText(
            "最初から",
            in: restartRect,
            alignment: .right,
            font: NSFont.systemFont(ofSize: 11),
            color: .controlAccentColor
        )
    }

    private var backRect: NSRect {
        NSRect(x: 16, y: 8, width: 96, height: 34)
    }

    private var restartRect: NSRect {
        NSRect(x: bounds.width - 92, y: 8, width: 76, height: 34)
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

    private func drawText(
        _ value: String,
        in rect: NSRect,
        alignment: NSTextAlignment,
        font: NSFont,
        color: NSColor
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let text = value as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(
            in: NSRect(
                x: rect.minX,
                y: rect.midY - size.height / 2,
                width: rect.width,
                height: size.height
            ),
            withAttributes: attributes
        )
    }
}

/// What the time panel ended with: a time to choose a format for, or a
/// range to insert as it is
enum TimePanelResult: Equatable {
    case time(TimeSelectionState)
    case range(TimeRangeSelection)
}

final class TimeWindowController: NSObject {
    private let panel: TimePanel
    private let inputView: TimeInputView
    private let rangeView: TimeRangeView
    private let formatKeyPanel = FormatKeyPanel()
    private var selectedTime: TimeSelectionState?
    private var selectedRange: TimeRangeSelection?
    /// The range left for the clock, offered again while the clock keeps
    /// the time it had then
    private var leftRange: (range: TimeRangeSelection, clockTime: TimeSelectionState)?
    private var anchorFrame: NSRect = .zero
    private var outsideLocalMonitor: Any?
    private var outsideGlobalMonitor: Any?
    private var outsideClickTimer: Timer?

    override init() {
        let layout = TimeDialLayout()
        let size = NSSize(
            width: CGFloat(layout.panelWidth),
            height: CGFloat(layout.panelHeight)
        )
        inputView = TimeInputView(frame: NSRect(origin: .zero, size: size))
        rangeView = TimeRangeView(frame: NSRect(
            origin: .zero,
            size: NSSize(width: size.width, height: TimeRangeView.height)
        ))
        panel = TimePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.animationBehavior = .none
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [
            .moveToActiveSpace, .transient, .fullScreenAuxiliary
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView?.addSubview(inputView)
        inputView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(rangeView)
        rangeView.autoresizingMask = [.width, .height]
        rangeView.isHidden = true
        panel.cancelAction = { [weak self] in self?.handleEscape() }
        panel.shortcutAction = { [weak self] in self?.handleShortcut() }
        inputView.cancelAction = { [weak self] in self?.cancelSelection() }
        inputView.confirmAction = { [weak self] state in self?.confirmSelection(state) }
        rangeView.cancelAction = { [weak self] in self?.cancelSelection() }
        rangeView.clockAction = { [weak self] in self?.showClock() }
        rangeView.confirmAction = { [weak self] range in
            self?.selectedRange = range
            NSApp.stopModal(withCode: .OK)
        }
    }

    var isVisible: Bool { panel.isVisible }

    private var isShowingRange: Bool { !rangeView.isHidden }

    /// Switches the panel to the rail, at `range` or else starting at the
    /// clock's time
    private func showRange(_ range: TimeRangeSelection? = nil) {
        let clockTime = inputView.currentTime
        let kept = leftRange.flatMap { $0.clockTime == clockTime ? $0.range : nil }
        rangeView.begin(
            with: range ?? kept ?? TimeRangeSelection(startingAt: clockTime)
        )
        inputView.isHidden = true
        rangeView.isHidden = false
        resize(toHeight: TimeRangeView.height)
        panel.makeFirstResponder(rangeView)
    }

    /// Back to the clock, which keeps its time
    private func showClock() {
        guard isShowingRange else { return }
        leftRange = (rangeView.range, inputView.currentTime)
        rangeView.isHidden = true
        inputView.isHidden = false
        resize(toHeight: CGFloat(TimeDialLayout().panelHeight))
        inputView.takeKeyboard()
    }

    private func resize(toHeight height: CGFloat) {
        guard panel.frame.height != height else { return }
        panel.setContentSize(NSSize(width: panel.frame.width, height: height))
        // Autoresizing would take the panel's change of height from each
        // view, leaving the shorter range view no height at all
        let bounds = panel.contentView?.bounds ?? .zero
        inputView.frame = bounds
        rangeView.frame = bounds
        position(near: anchorFrame)
        panel.invalidateShadow()
    }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard panel.isVisible else { return false }
        if MyIMFeatureShortcut.time.shortcut.matches(event) {
            handleShortcut()
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
            handleEscape()
            return true
        }
        if isShowingRange {
            rangeView.handleKey(event)
        } else {
            inputView.keyDown(with: event)
        }
        return true
    }

    /// `initialTime` reopens the clock at a time chosen before and
    /// `initialRange` the rail at a range chosen before; without them the
    /// clock starts at the current time
    func runSelection(
        near anchorFrame: NSRect,
        initialTime: TimeSelectionState? = nil,
        initialStage: TimeInputStage = .period,
        initialRange: TimeRangeSelection? = nil,
        initialDate: Date = Date()
    ) -> TimePanelResult? {
        selectedTime = nil
        selectedRange = nil
        self.anchorFrame = anchorFrame
        showClock()
        leftRange = nil
        if let initialRange {
            inputView.setTime(
                TimeSelectionState(
                    hour: initialRange.start / 60,
                    minute: initialRange.start % 60
                )!,
                stage: .minute
            )
            showRange(initialRange)
        } else if let initialTime {
            inputView.setTime(initialTime, stage: initialStage)
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
        if isShowingRange {
            panel.makeFirstResponder(rangeView)
        } else {
            inputView.takeKeyboard()
        }
        startOutsideClickMonitoring()
        let response = NSApp.runModal(for: panel)
        stopOutsideClickMonitoring()
        panel.orderOut(nil)
        if NSApp.activationPolicy() != previousPolicy {
            _ = NSApp.setActivationPolicy(previousPolicy)
        }
        guard response == .OK else { return nil }
        if let selectedRange { return .range(selectedRange) }
        return selectedTime.map(TimePanelResult.time)
    }

    /// The formats are shown in the candidate panel by the caller, as the
    /// calendar's are; the time panel closes and an almost invisible panel
    /// takes the keys until one is chosen or Esc goes back
    func runFormatSelection(
        candidateCount: Int,
        near anchorFrame: NSRect,
        directionalSelection: @escaping (Int?, CandidateNavigationDirection) -> Int?,
        selectionChanged: @escaping (Int?) -> Void
    ) -> TimeFormatSelectionOutcome {
        guard candidateCount > 0 else { return .closed }
        stopOutsideClickMonitoring()
        panel.orderOut(nil)
        formatKeyPanel.candidateCount = candidateCount
        formatKeyPanel.selectedIndex = nil
        formatKeyPanel.directionalSelection = directionalSelection
        formatKeyPanel.selectionChanged = selectionChanged
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        formatKeyPanel.setFrameOrigin(anchorFrame.origin)
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

    var isSelectingFormat: Bool { NSApp.modalWindow === formatKeyPanel }

    /// A key the input method received while the formats are chosen, handled
    /// as the key panel handles its own
    func handleFormatKey(_ event: NSEvent) {
        guard isSelectingFormat else { return }
        formatKeyPanel.keyDown(with: event)
    }

    /// Ends the format selection as Esc does, going back to the clock or rail
    func cancelFormatSelection() {
        guard isSelectingFormat else { return }
        NSApp.stopModal(withCode: .cancel)
    }

    func hide() {
        stopOutsideClickMonitoring()
        if NSApp.modalWindow === panel || NSApp.modalWindow === formatKeyPanel {
            NSApp.abortModal()
        }
        panel.orderOut(nil)
        formatKeyPanel.orderOut(nil)
    }

    /// Each press switches between the clock and the rail; only Esc closes
    /// the panel, and the formats stay as they are
    private func handleShortcut() {
        if isShowingRange {
            showClock()
        } else {
            showRange()
        }
    }

    func handleEscape() {
        if isShowingRange {
            cancelSelection()
        } else if !inputView.moveBack() {
            cancelSelection()
        }
    }

    private func confirmSelection(_ state: TimeSelectionState) {
        selectedTime = state
        NSApp.stopModal(withCode: .OK)
    }

    private func cancelSelection() {
        selectedTime = nil
        if NSApp.modalWindow === panel { NSApp.abortModal() }
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
