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
    var formatSelectionChanged: ((Int?) -> Void)?
    var formatCommitAction: ((Int) -> Void)?
    var formatBackAction: (() -> Void)?
    var formatRestartAction: (() -> Void)?

    private let dialView = TimeDialView()
    private var flow = TimeInputFlow(
        time: TimeSelectionState(hour: 0, minute: 0)!
    )
    private var formatCandidates: [String]?
    private var selectedFormatIndex: Int?
    private var directionalSelection: ((Int?, CandidateNavigationDirection) -> Int?)?
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
        formatCandidates = nil
        selectedFormatIndex = nil
        dialView.isHidden = false
        dialView.flow = flow
        needsDisplay = true
    }

    func showFormats(
        _ candidates: [String],
        directionalSelection: @escaping (
            Int?, CandidateNavigationDirection
        ) -> Int?
    ) {
        arrowSequence.reset()
        formatCandidates = candidates
        selectedFormatIndex = nil
        self.directionalSelection = directionalSelection
        dialView.isHidden = true
        needsDisplay = true
    }

    func clearFormats() {
        arrowSequence.reset()
        formatCandidates = nil
        selectedFormatIndex = nil
        directionalSelection = nil
        formatSelectionChanged = nil
        formatCommitAction = nil
        formatBackAction = nil
        formatRestartAction = nil
    }

    var isShowingFormats: Bool { formatCandidates != nil }

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
        if formatCandidates != nil { drawFormatStage() }
        drawFooter()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if backRect.contains(point) {
            if formatCandidates != nil {
                formatBackAction?()
            } else if !moveBack() {
                cancelAction?()
            }
            return
        }
        if restartRect.contains(point) {
            if formatCandidates != nil {
                formatRestartAction?()
            } else {
                restart()
            }
            return
        }
        guard let index = formatIndex(at: point) else { return }
        selectedFormatIndex = index
        formatSelectionChanged?(index)
        needsDisplay = true
        formatCommitAction?(index)
    }

    override func keyDown(with event: NSEvent) {
        if formatCandidates != nil {
            handleFormatKey(event)
            return
        }
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

    private func handleFormatKey(_ event: NSEvent) {
        switch event.keyCode {
        case 48:
            moveFormatSelection(
                by: event.modifierFlags.contains(.shift) ? -1 : 1
            )
        case 123, 124, 125, 126:
            let direction: CandidateNavigationDirection = switch event.keyCode {
            case 123: .left
            case 124: .right
            case 125: .down
            default: .up
            }
            selectedFormatIndex = directionalSelection?(
                selectedFormatIndex,
                direction
            )
            formatSelectionChanged?(selectedFormatIndex)
            needsDisplay = true
        case 36, 76:
            if let selectedFormatIndex {
                formatCommitAction?(selectedFormatIndex)
            }
        case 53:
            formatBackAction?()
        default:
            break
        }
    }

    private func moveFormatSelection(by offset: Int) {
        guard let formatCandidates, !formatCandidates.isEmpty else { return }
        let current = selectedFormatIndex ?? (offset > 0 ? -1 : 0)
        selectedFormatIndex = (
            current + offset + formatCandidates.count
        ) % formatCandidates.count
        formatSelectionChanged?(selectedFormatIndex)
        needsDisplay = true
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
        if formatCandidates != nil { return 3 }
        return switch flow.stage {
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
        let heading = if formatCandidates != nil {
            "書式を選択"
        } else {
            switch flow.stage {
            case .period: "午前・午後を選択"
            case .hour: "時を選択"
            case .minute: "分を選択"
            }
        }
        drawCentered(
            heading,
            at: NSPoint(x: bounds.midX, y: bounds.height - 63),
            font: NSFont.systemFont(ofSize: 17, weight: .semibold),
            color: .labelColor
        )
    }

    private func drawFormatStage() {
        guard let formatCandidates else { return }
        drawCentered(
            flow.time.digitalText,
            at: NSPoint(x: bounds.midX, y: bounds.height - 108),
            font: NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold),
            color: .labelColor
        )
        let subtitle = "\(flow.time.period == .am ? "午前" : "午後") \(flow.time.twelveHour):\(String(format: "%02d", flow.time.minute))"
        drawCentered(
            subtitle,
            at: NSPoint(x: bounds.midX, y: bounds.height - 137),
            font: NSFont.systemFont(ofSize: 12),
            color: .secondaryLabelColor
        )
        for index in visibleFormatIndices {
            let rect = formatRowRect(for: index)
            let selected = selectedFormatIndex == index
            let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
            (selected
                ? NSColor.controlAccentColor.withAlphaComponent(0.16)
                : NSColor.controlBackgroundColor).setFill()
            path.fill()
            (selected ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            path.lineWidth = selected ? 1.5 : 0.5
            path.stroke()
            drawText(
                String(index + 1),
                in: NSRect(x: rect.minX + 12, y: rect.minY, width: 24, height: rect.height),
                alignment: .left,
                font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                color: .secondaryLabelColor
            )
            drawText(
                formatCandidates[index],
                in: NSRect(x: rect.minX + 42, y: rect.minY, width: rect.width - 116, height: rect.height),
                alignment: .left,
                font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium),
                color: .labelColor
            )
            drawText(
                "書式 \(index + 1)",
                in: NSRect(x: rect.maxX - 70, y: rect.minY, width: 58, height: rect.height),
                alignment: .right,
                font: NSFont.systemFont(ofSize: 10),
                color: .secondaryLabelColor
            )
        }
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

    private var visibleFormatIndices: Range<Int> {
        guard let formatCandidates else { return 0..<0 }
        let pageSize = 4
        let page = (selectedFormatIndex ?? 0) / pageSize
        let start = page * pageSize
        return start..<min(start + pageSize, formatCandidates.count)
    }

    private func formatRowRect(for index: Int) -> NSRect {
        let position = index - visibleFormatIndices.lowerBound
        return NSRect(
            x: 24,
            y: bounds.height - 194 - CGFloat(position) * 50,
            width: bounds.width - 48,
            height: 40
        )
    }

    private func formatIndex(at point: NSPoint) -> Int? {
        guard formatCandidates != nil else { return nil }
        return visibleFormatIndices.first(where: {
            formatRowRect(for: $0).contains(point)
        })
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

final class TimeWindowController: NSObject {
    private static let restartModalResponse = NSApplication.ModalResponse(
        rawValue: 1_001
    )
    private let panel: TimePanel
    private let inputView: TimeInputView
    private var selectedTime: TimeSelectionState?
    private var selectedFormatIndex: Int?
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
        panel.cancelAction = { [weak self] in self?.handleEscape() }
        inputView.cancelAction = { [weak self] in self?.cancelSelection() }
        inputView.confirmAction = { [weak self] state in self?.confirmSelection(state) }
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
            handleEscape()
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
        initialStage: TimeInputStage = .period,
        initialDate: Date = Date()
    ) -> TimeSelectionState? {
        selectedTime = nil
        if let initialTime {
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
        candidates: [String],
        near anchorFrame: NSRect,
        directionalSelection: @escaping (Int?, CandidateNavigationDirection) -> Int?,
        selectionChanged: @escaping (Int?) -> Void
    ) -> TimeFormatSelectionOutcome {
        guard !candidates.isEmpty else { return .closed }
        selectedFormatIndex = nil
        inputView.showFormats(
            candidates,
            directionalSelection: directionalSelection
        )
        inputView.formatSelectionChanged = { [weak self] index in
            self?.selectedFormatIndex = index
            selectionChanged(index)
        }
        inputView.formatCommitAction = { [weak self] index in
            self?.selectedFormatIndex = index
            NSApp.stopModal(withCode: .OK)
        }
        inputView.formatBackAction = {
            NSApp.stopModal(withCode: .cancel)
        }
        inputView.formatRestartAction = {
            NSApp.stopModal(withCode: Self.restartModalResponse)
        }
        position(near: anchorFrame)
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        panel.makeKeyAndOrderFront(nil)
        inputView.takeKeyboard()
        startOutsideClickMonitoring()
        let response = NSApp.runModal(for: panel)
        stopOutsideClickMonitoring()
        let result = selectedFormatIndex
        panel.orderOut(nil)
        inputView.clearFormats()
        if NSApp.activationPolicy() != previousPolicy {
            _ = NSApp.setActivationPolicy(previousPolicy)
        }
        switch response {
        case .OK:
            return result.map(TimeFormatSelectionOutcome.selected) ?? .closed
        case .cancel:
            return .returnToTime
        case Self.restartModalResponse:
            return .restartTime
        default:
            return .closed
        }
    }

    func hide() {
        stopOutsideClickMonitoring()
        if NSApp.modalWindow === panel {
            NSApp.abortModal()
        }
        panel.orderOut(nil)
        inputView.clearFormats()
    }

    func handleEscape() {
        if inputView.isShowingFormats {
            inputView.formatBackAction?()
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
