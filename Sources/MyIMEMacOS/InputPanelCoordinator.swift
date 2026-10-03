@preconcurrency import AppKit
import MyIMECore

final class InputPanelCoordinator {
    let candidate = CandidateWindowController()
    let candidateFilterDraft = CandidateWindowController()
    private var candidateFilterConditions: [CandidateWindowController] = []
    let calendar = CalendarWindowController()
    let emoji = EmojiWindowController.shared
    let fuzzySuggestion = FuzzySuggestionWindowController()
    let translationCandidate = CandidateWindowController()
    let externalInformation = ExternalInformationWindowController()
    let symbolTips = SymbolTipsWindowController()
    private var nextInputDismissTimer: Timer?
    private var nextInputOutsideLocalMonitor: Any?
    private var nextInputOutsideGlobalMonitor: Any?
    private var calendarAnchorFrame: NSRect?
    private var calendarReturnApplication: NSRunningApplication?

    deinit {
        stopNextInputLifecycle()
    }

    func scheduleNextInputDismissal(
        after interval: TimeInterval,
        onDismiss: @escaping () -> Void
    ) {
        cancelNextInputDismissal()
        nextInputDismissTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] timer in
            guard let self,
                  timer === nextInputDismissTimer else { return }
            nextInputDismissTimer = nil
            onDismiss()
        }
    }

    func cancelNextInputDismissal() {
        nextInputDismissTimer?.invalidate()
        nextInputDismissTimer = nil
    }

    func startNextInputOutsideClickMonitoring(
        onDismiss: @escaping () -> Void
    ) {
        stopNextInputOutsideClickMonitoring()
        let mouseEvents: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown
        ]
        nextInputOutsideLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: mouseEvents
        ) { [weak self] event in
            self?.dismissNextInputIfClickedOutside(onDismiss: onDismiss)
            return event
        }
        nextInputOutsideGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: mouseEvents
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.dismissNextInputIfClickedOutside(onDismiss: onDismiss)
            }
        }
    }

    func stopNextInputLifecycle() {
        cancelNextInputDismissal()
        stopNextInputOutsideClickMonitoring()
    }

    private func stopNextInputOutsideClickMonitoring() {
        if let monitor = nextInputOutsideLocalMonitor {
            NSEvent.removeMonitor(monitor)
            nextInputOutsideLocalMonitor = nil
        }
        if let monitor = nextInputOutsideGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            nextInputOutsideGlobalMonitor = nil
        }
    }

    private func dismissNextInputIfClickedOutside(
        onDismiss: () -> Void
    ) {
        guard !candidate.contains(screenPoint: NSEvent.mouseLocation) else {
            return
        }
        onDismiss()
    }

    func beginCalendarSelection(
        near anchorFrame: NSRect,
        returnTo application: NSRunningApplication?
    ) -> Date? {
        calendarAnchorFrame = anchorFrame == .zero ? nil : anchorFrame
        calendarReturnApplication = application
        return calendar.runSelection(
            near: calendarAnchorFrame ?? anchorFrame,
            returnTo: calendarReturnApplication
        )
    }

    func runCalendarFormatSelection(
        candidateCount: Int,
        fallbackLocation: NSRect,
        directionalSelection: @escaping (Int?, CandidateNavigationDirection) -> Int?,
        selectionChanged: @escaping (Int?) -> Void
    ) -> Int? {
        calendar.runFormatSelection(
            candidateCount: candidateCount,
            near: calendarInputLocation(fallback: fallbackLocation),
            returnTo: calendarReturnApplication,
            directionalSelection: directionalSelection,
            selectionChanged: selectionChanged
        )
    }

    func calendarInputLocation(fallback: NSRect) -> NSRect {
        calendarAnchorFrame ?? fallback
    }

    func clearCalendarPresentation() {
        calendarAnchorFrame = nil
        calendarReturnApplication = nil
        calendar.hide()
    }

    func showFilterConditions(
        _ labels: [String],
        near anchorFrame: NSRect
    ) {
        while candidateFilterConditions.count < labels.count {
            candidateFilterConditions.append(CandidateWindowController())
        }
        while candidateFilterConditions.count > labels.count {
            candidateFilterConditions.removeLast().hide()
        }
        for (window, label) in zip(candidateFilterConditions, labels) {
            window.show(
                candidates: [label],
                selectedIndex: nil,
                near: anchorFrame
            )
        }
    }

    func layoutFilterPanels(includingDraft: Bool) {
        let windows = candidateFilterConditions
            + (includingDraft ? [candidateFilterDraft] : [])
        guard !windows.isEmpty else { return }
        let spacing: CGFloat = 8
        let requiredWidth = windows.reduce(0) { $0 + $1.frame.width }
            + spacing * CGFloat(windows.count)
        candidate.makeRoomOnRight(width: requiredWidth, spacing: 0)
        var offset = spacing
        for window in windows {
            window.placeBeside(candidate.frame, spacing: offset)
            offset += window.frame.width + spacing
        }
    }

    func hideFilterConditions() {
        candidateFilterConditions.forEach { $0.hide() }
        candidateFilterConditions.removeAll(keepingCapacity: true)
    }

    func prepareCandidateAnchorForFuzzyPanel(
        width: CGFloat,
        spacing: CGFloat
    ) -> NSRect {
        candidate.makeRoomOnRight(width: width, spacing: spacing)
        return candidate.frame
    }

    func alignFuzzySuggestionToCandidateRight() {
        guard fuzzySuggestion.isVisible else { return }
        candidate.makeRoomOnRight(
            width: fuzzySuggestion.panelWidth,
            spacing: fuzzySuggestion.spacingFromCandidatePanel
        )
        fuzzySuggestion.reposition(
            near: candidate.frame,
            avoidingFrames: [candidate.frame] + candidate.auxiliaryFrames
        )
    }

    func reserveTranslationCandidateSpace(onLeft: Bool) {
        guard !translationCandidate.isVisible else {
            keepCandidateGroupInsideScreen()
            return
        }
        let reservedWidth = CandidatePanelItemStyle.maximumWidth + 8
        keepCandidateGroupInsideScreen(
            reservedLeftWidth: onLeft ? reservedWidth : 0,
            reservedRightWidth: onLeft ? 0 : reservedWidth
        )
    }

    func keepCandidateGroupInsideScreen(
        reservedLeftWidth: CGFloat = 0,
        reservedRightWidth: CGFloat = 0
    ) {
        let frames = [
            candidate.visibleFrame,
            fuzzySuggestion.visibleFrame,
            translationCandidate.visibleFrame
        ].compactMap { $0 }
        guard let firstFrame = frames.first,
              let visibleFrame = NSScreen.inputScreen(
                containing: candidate.frame
              )?.visibleFrame else { return }
        let groupFrame = frames.dropFirst().reduce(firstFrame) {
            $0.union($1)
        }
        let offset = HorizontalPanelGroupPlacement.offset(
            groupMinX: groupFrame.minX,
            groupMaxX: groupFrame.maxX,
            visibleMinX: visibleFrame.minX,
            visibleMaxX: visibleFrame.maxX,
            reservedLeftWidth: reservedLeftWidth,
            reservedRightWidth: reservedRightWidth
        )
        candidate.offsetHorizontally(by: offset)
        fuzzySuggestion.offsetHorizontally(by: offset)
        translationCandidate.offsetHorizontally(by: offset)
    }

    func hideConversionPanels() {
        candidate.hide()
        fuzzySuggestion.hide()
        translationCandidate.hide()
        externalInformation.hide()
    }

    func dismiss(using policy: InputPanelDismissalPolicy) {
        stopNextInputLifecycle()
        if policy.cancelsCalendarWork {
            candidate.hide()
        }
        fuzzySuggestion.hide()
        emoji.hide()
        symbolTips.hide()
        candidateFilterDraft.hide()
        hideFilterConditions()
        if !policy.preservesExternalInformation {
            externalInformation.hide()
        }
        if !policy.preservesCalendar {
            clearCalendarPresentation()
        }
    }

    func dismissAll() {
        stopNextInputLifecycle()
        candidate.hide()
        fuzzySuggestion.hide()
        translationCandidate.hide()
        emoji.hide()
        externalInformation.hide()
        symbolTips.hide()
        candidateFilterDraft.hide()
        hideFilterConditions()
        clearCalendarPresentation()
    }
}
