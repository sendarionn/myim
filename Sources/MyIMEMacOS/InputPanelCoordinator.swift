@preconcurrency import AppKit
import MyIMECore

final class InputPanelCoordinator {
    let candidate = CandidateWindowController()
    let candidateFilterDraft = CandidateWindowController()
    private var candidateFilterConditions: [CandidateWindowController] = []
    let calendar = CalendarWindowController()
    let emoji = EmojiWindowController.shared
    let fuzzySuggestion = FuzzySuggestionWindowController()
    /// One panel per target language with results, nearest to the source
    /// first; panels beyond the current count are kept hidden for reuse
    private var translationCandidates: [CandidateWindowController] = []
    private var visibleTranslationCandidateCount = 0
    let externalInformation = ExternalInformationWindowController()
    let symbolTips = SymbolTipsWindowController()
    private var nextInputDismissTimer: Timer?
    private var nextInputOutsideLocalMonitor: Any?
    private var nextInputOutsideGlobalMonitor: Any?
    private var calendarAnchorFrame: NSRect?
    private var calendarReturnApplication: NSRunningApplication?

    var visiblePanelKinds: Set<InputPanelKind> {
        var result = Set<InputPanelKind>()
        if candidate.isVisible {
            result.insert(.candidate)
        }
        if fuzzySuggestion.isVisible {
            result.insert(.fuzzySuggestion)
        }
        if translationCandidates.contains(where: \.isVisible) {
            result.insert(.translationCandidates)
        }
        if emoji.isVisible {
            result.insert(.emoji)
        }
        if externalInformation.isVisible {
            result.insert(.externalInformation)
        }
        if symbolTips.isVisible {
            result.insert(.symbolTips)
        }
        if candidateFilterDraft.isVisible {
            result.insert(.candidateFilterDraft)
        }
        if candidateFilterConditions.contains(where: \.isVisible) {
            result.insert(.candidateFilterConditions)
        }
        if calendar.isVisible {
            result.insert(.calendar)
        }
        return result
    }

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

    static let translationPanelSpacing: CGFloat = 8

    var visibleTranslationCandidateFrames: [NSRect] {
        translationCandidates.prefix(visibleTranslationCandidateCount)
            .compactMap(\.visibleFrame)
    }

    /// Keeps room for `languageCount` panels before any translation has
    /// arrived, so panels appearing later do not push the candidates aside
    func reserveTranslationCandidateSpace(
        languageCount: Int,
        onLeft: Bool
    ) {
        guard visibleTranslationCandidateCount == 0 else {
            keepCandidateGroupInsideScreen()
            return
        }
        guard let groupFrame = conversionGroupFrame(),
              let visibleFrame = NSScreen.inputScreen(
                containing: candidate.frame
              )?.visibleFrame else { return }
        let reservedWidth = HorizontalPanelGroupPlacement.reservedWidth(
            panelCount: languageCount,
            panelWidth: CandidatePanelItemStyle.maximumWidth,
            spacing: Self.translationPanelSpacing,
            groupWidth: groupFrame.width,
            visibleWidth: visibleFrame.width
        )
        keepCandidateGroupInsideScreen(
            reservedLeftWidth: onLeft ? reservedWidth : 0,
            reservedRightWidth: onLeft ? 0 : reservedWidth
        )
    }

    /// Shows one panel per group, extending away from `sourceFrame`, and
    /// returns how many fit on the screen; the outermost ones are dropped
    /// rather than shrunk when the screen is too narrow
    @discardableResult
    func showTranslationCandidates(
        _ panels: [(candidates: [String], caption: String?)],
        beside sourceFrame: NSRect,
        onLeft: Bool,
        near anchorFrame: NSRect
    ) -> Int {
        hideTranslationCandidates()
        while translationCandidates.count < panels.count {
            translationCandidates.append(CandidateWindowController())
        }
        var previousFrame = sourceFrame
        for (window, panel) in zip(translationCandidates, panels) {
            window.show(
                candidates: panel.candidates,
                selectedIndex: nil,
                near: anchorFrame,
                caption: panel.caption,
                isAccented: false
            )
            if onLeft {
                window.placeLeft(
                    of: previousFrame,
                    spacing: Self.translationPanelSpacing
                )
            } else {
                window.placeRight(
                    of: previousFrame,
                    spacing: Self.translationPanelSpacing
                )
            }
            previousFrame = window.frame
        }
        visibleTranslationCandidateCount = panels.count
        if let groupFrame = conversionGroupFrame(),
           let visibleFrame = NSScreen.inputScreen(
            containing: candidate.frame
           )?.visibleFrame {
            let fitting = HorizontalPanelGroupPlacement.fittingPanelCount(
                panelWidths: translationCandidates.prefix(panels.count)
                    .map { ($0.visibleFrame ?? $0.frame).width },
                spacing: Self.translationPanelSpacing,
                groupWidth: groupFrame.width,
                visibleWidth: visibleFrame.width
            )
            translationCandidates[fitting..<panels.count].forEach {
                $0.hide()
            }
            visibleTranslationCandidateCount = fitting
        }
        keepCandidateGroupInsideScreen()
        return visibleTranslationCandidateCount
    }

    func selectTranslationCandidate(_ selection: TranslationCandidateSelection) {
        for (groupIndex, window) in translationCandidates
            .prefix(visibleTranslationCandidateCount).enumerated() {
            if groupIndex == selection.groupIndex {
                window.select(index: selection.candidateIndex)
            } else {
                window.clearSelection()
            }
        }
    }

    func clearTranslationCandidateSelection() {
        translationCandidates.forEach { $0.clearSelection() }
    }

    func hideTranslationCandidates() {
        translationCandidates.forEach { $0.hide() }
        visibleTranslationCandidateCount = 0
    }

    /// Normal candidates and fuzzy suggestions, without translations
    private func conversionGroupFrame() -> NSRect? {
        let frames = [
            candidate.visibleFrame,
            fuzzySuggestion.visibleFrame
        ].compactMap { $0 }
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }
    }

    func keepCandidateGroupInsideScreen(
        reservedLeftWidth: CGFloat = 0,
        reservedRightWidth: CGFloat = 0
    ) {
        let frames = [
            candidate.visibleFrame,
            fuzzySuggestion.visibleFrame
        ].compactMap { $0 } + visibleTranslationCandidateFrames
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
        translationCandidates.prefix(visibleTranslationCandidateCount)
            .forEach { $0.offsetHorizontally(by: offset) }
    }

    func hideConversionPanels() {
        candidate.hide()
        fuzzySuggestion.hide()
        hideTranslationCandidates()
        externalInformation.hide()
    }

    func dismissNextInputPresentation() {
        stopNextInputLifecycle()
        candidate.hide()
        externalInformation.hide()
    }

    func dismiss(
        using policy: InputPanelDismissalPolicy,
        hidesSharedEmoji: Bool
    ) {
        stopNextInputLifecycle()
        for panel in policy.panelsToDismiss {
            switch panel {
            case .candidate:
                candidate.hide()
            case .fuzzySuggestion:
                fuzzySuggestion.hide()
            case .translationCandidates:
                hideTranslationCandidates()
            case .emoji:
                if hidesSharedEmoji {
                    emoji.hide()
                }
            case .externalInformation:
                externalInformation.hide()
            case .symbolTips:
                symbolTips.hide()
            case .candidateFilterDraft:
                candidateFilterDraft.hide()
            case .candidateFilterConditions:
                hideFilterConditions()
            case .calendar:
                clearCalendarPresentation()
            }
        }
    }

    func dismissAll(hidesSharedEmoji: Bool) {
        dismiss(
            using: .inputBecameEmpty,
            hidesSharedEmoji: hidesSharedEmoji
        )
    }
}
