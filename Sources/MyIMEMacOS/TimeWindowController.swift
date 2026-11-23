@preconcurrency import AppKit
import MyIMECore

private final class TimePanel: NSPanel {
    var cancelAction: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        cancelAction?()
    }

    /// The time shortcut pressed while the panel has the keys
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           MyIMFeatureShortcut.time.shortcut.matches(event) {
            return
        }
        super.sendEvent(event)
    }
}

/// What the unified time rail ended with
enum TimePanelResult: Equatable {
    case time(TimeSelectionState)
    case range(TimeRangeSelection)
}

final class TimeWindowController: NSObject {
    private let panel: TimePanel
    private let rangeView: TimeRangeView
    private let formatKeyPanel = FormatKeyPanel()
    private var selectedTime: TimeSelectionState?
    private var selectedRange: TimeRangeSelection?
    private var anchorFrame: NSRect = .zero
    private var outsideLocalMonitor: Any?
    private var outsideGlobalMonitor: Any?
    private var outsideClickTimer: Timer?

    override init() {
        let size = NSSize(width: 332, height: TimeRangeView.height)
        rangeView = TimeRangeView(frame: NSRect(
            origin: .zero,
            size: size
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
        panel.hasShadow = false
        panel.contentView?.addSubview(rangeView)
        rangeView.autoresizingMask = [.width, .height]
        panel.cancelAction = { [weak self] in self?.handleEscape() }
        rangeView.cancelAction = { [weak self] in self?.handleEscape() }
        rangeView.closeAction = { [weak self] in self?.cancelSelection() }
        rangeView.timeAction = { [weak self] time in
            self?.selectedTime = time
            NSApp.stopModal(withCode: .OK)
        }
        rangeView.rangeAction = { [weak self] range in
            self?.selectedRange = range
            NSApp.stopModal(withCode: .OK)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard panel.isVisible else { return false }
        if MyIMFeatureShortcut.time.shortcut.matches(event) {
            return true
        }
        let modifiers = event.shortcutModifiers
        if !modifiers.intersection([.command, .control, .option]).isEmpty {
            hide()
            return false
        }
        if event.keyCode == 53 {
            handleEscape()
            return true
        }
        // Delete closes without choosing a time and never reaches the
        // application, where it would delete text
        if event.keyCode == 51 {
            cancelSelection()
            return true
        }
        rangeView.handleKey(event)
        return true
    }

    /// Reopens the unified rail at a previously selected time or range
    func runSelection(
        near anchorFrame: NSRect,
        initialTime: TimeSelectionState? = nil,
        initialRange: TimeRangeSelection? = nil,
        initialDate: Date = Date()
    ) -> TimePanelResult? {
        selectedTime = nil
        selectedRange = nil
        self.anchorFrame = anchorFrame
        if let initialRange {
            rangeView.begin(with: initialRange)
        } else if let initialTime {
            rangeView.begin(with: initialTime)
        } else {
            let components = Calendar.current.dateComponents(
                [.hour, .minute],
                from: initialDate
            )
            let time = TimeSelectionState(
                hour: components.hour ?? 0,
                minute: components.minute ?? 0
            ) ?? TimeSelectionState(hour: 0, minute: 0)!
            rangeView.begin(with: time)
        }
        position(near: anchorFrame)
        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy == .prohibited {
            _ = NSApp.setActivationPolicy(.accessory)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        panel.makeFirstResponder(rangeView)
        startOutsideClickMonitoring()
        let response = NSApp.runModal(for: panel)
        // A knob held when the panel closed leaves no timer behind
        rangeView.endDrag()
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

    /// Ends the format selection as Esc does, going back to the rail
    func cancelFormatSelection() {
        guard isSelectingFormat else { return }
        NSApp.stopModal(withCode: .cancel)
    }

    func hide() {
        rangeView.endDrag()
        stopOutsideClickMonitoring()
        if NSApp.modalWindow === panel || NSApp.modalWindow === formatKeyPanel {
            NSApp.abortModal()
        }
        panel.orderOut(nil)
        formatKeyPanel.orderOut(nil)
    }

    func handleEscape() {
        if !rangeView.returnToTimeMode() { cancelSelection() }
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
        guard panel.isVisible,
              !rangeView.isDragging,
              !panel.frame.contains(point) else { return }
        cancelSelection()
    }
}
