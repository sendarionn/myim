@preconcurrency import AppKit
import MyIMECore

final class InputPanelCoordinator {
    let primaryCandidatePanel = CandidatePanelController()
    let candidateFilterDraft = CandidatePanelController()
    private var candidateFilterConditions: [CandidatePanelController] = []
    let calendar = CalendarWindowController()
    let time = TimeWindowController()
    let emoji = EmojiWindowController.shared
    let secondaryCandidatePanel = SecondaryCandidatePanelController()
    /// One panel per target language with results, nearest to the source
    /// first; panels beyond the current count are kept hidden for reuse
    private var translationCandidates: [CandidatePanelController] = []
    private var visibleTranslationCandidateCount = 0
    let externalInformation = ExternalInformationWindowController()
    let symbolTips = SymbolTipsWindowController()
    /// The next-input panel closes after this long without an operation
    static let nextInputDismissInterval: TimeInterval = 5
    private let nextInputDismissal = InactivityDismissal(
        interval: nextInputDismissInterval
    ) { interval, action in
        let timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { _ in action() }
        return { timer.invalidate() }
    }
    private var nextInputOutsideLocalMonitor: Any?
    private var nextInputOutsideGlobalMonitor: Any?
    private var calendarAnchorFrame: NSRect?
    private var calendarReturnApplication: NSRunningApplication?
    private var timeAnchorFrame: NSRect?

    var visiblePanelKinds: Set<InputPanelKind> {
        var result = Set<InputPanelKind>()
        if primaryCandidatePanel.isVisible {
            result.insert(.primaryCandidatePanel)
        }
        if secondaryCandidatePanel.isVisible {
            result.insert(.secondaryCandidatePanel)
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
        if time.isVisible { result.insert(.time) }
        return result
    }

    deinit {
        stopNextInputLifecycle()
    }

    /// Counts the timeout again from now, for a newly shown panel or an
    /// operation on it
    func restartNextInputDismissal(onDismiss: @escaping () -> Void) {
        nextInputDismissal.restart(onDismiss: onDismiss)
    }

    /// Keeps a running countdown, for candidates added in the background
    func startNextInputDismissalIfIdle(onDismiss: @escaping () -> Void) {
        nextInputDismissal.startIfIdle(onDismiss: onDismiss)
    }

    func cancelNextInputDismissal() {
        nextInputDismissal.cancel()
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
        guard !primaryCandidatePanel.contains(screenPoint: NSEvent.mouseLocation) else {
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

    func beginTimeSelection(near anchorFrame: NSRect) -> TimeSelectionState? {
        timeAnchorFrame = anchorFrame == .zero ? nil : anchorFrame
        return time.runSelection(near: timeAnchorFrame ?? anchorFrame)
    }

    /// Reopens the clock where it was, at the time chosen before
    func resumeTimeSelection(
        at initialTime: TimeSelectionState,
        fallback: NSRect
    ) -> TimeSelectionState? {
        time.runSelection(
            near: timeAnchorFrame ?? fallback,
            initialTime: initialTime
        )
    }

    func runTimeFormatSelection(
        candidateCount: Int,
        fallbackLocation: NSRect,
        directionalSelection: @escaping (Int?, CandidateNavigationDirection) -> Int?,
        selectionChanged: @escaping (Int?) -> Void
    ) -> TimeFormatSelectionOutcome {
        time.runFormatSelection(
            candidateCount: candidateCount,
            near: timeInputLocation(fallback: fallbackLocation),
            directionalSelection: directionalSelection,
            selectionChanged: selectionChanged
        )
    }

    func timeInputLocation(fallback: NSRect) -> NSRect {
        timeAnchorFrame ?? fallback
    }

    func clearTimePresentation() {
        timeAnchorFrame = nil
        time.hide()
    }

    func showFilterConditions(
        _ labels: [String],
        near anchorFrame: NSRect
    ) {
        while candidateFilterConditions.count < labels.count {
            candidateFilterConditions.append(CandidatePanelController())
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
        primaryCandidatePanel.makeRoomOnRight(width: requiredWidth, spacing: 0)
        var offset = spacing
        for window in windows {
            window.placeBeside(primaryCandidatePanel.frame, spacing: offset)
            offset += window.frame.width + spacing
        }
    }

    func hideFilterConditions() {
        candidateFilterConditions.forEach { $0.hide() }
        candidateFilterConditions.removeAll(keepingCapacity: true)
    }

    func prepareAnchorForSecondaryCandidatePanel(
        width: CGFloat,
        spacing: CGFloat
    ) -> NSRect {
        primaryCandidatePanel.makeRoomOnRight(width: width, spacing: spacing)
        return primaryCandidatePanel.frame
    }

    func alignSecondaryCandidatePanelToPrimary() {
        guard secondaryCandidatePanel.isVisible else { return }
        primaryCandidatePanel.makeRoomOnRight(
            width: secondaryCandidatePanel.panelWidth,
            spacing: secondaryCandidatePanel.spacingFromCandidatePanel
        )
        secondaryCandidatePanel.reposition(
            near: primaryCandidatePanel.frame,
            avoidingFrames: [primaryCandidatePanel.frame] + primaryCandidatePanel.auxiliaryFrames
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
                containing: primaryCandidatePanel.frame
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
            translationCandidates.append(CandidatePanelController())
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
            containing: primaryCandidatePanel.frame
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

    /// Primary and secondary candidate panels, without translations
    private func conversionGroupFrame() -> NSRect? {
        let frames = [
            primaryCandidatePanel.visibleFrame,
            secondaryCandidatePanel.visibleFrame
        ].compactMap { $0 }
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }
    }

    func keepCandidateGroupInsideScreen(
        reservedLeftWidth: CGFloat = 0,
        reservedRightWidth: CGFloat = 0
    ) {
        let frames = [
            primaryCandidatePanel.visibleFrame,
            secondaryCandidatePanel.visibleFrame
        ].compactMap { $0 } + visibleTranslationCandidateFrames
        guard let firstFrame = frames.first,
              let visibleFrame = NSScreen.inputScreen(
                containing: primaryCandidatePanel.frame
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
        primaryCandidatePanel.offsetHorizontally(by: offset)
        secondaryCandidatePanel.offsetHorizontally(by: offset)
        translationCandidates.prefix(visibleTranslationCandidateCount)
            .forEach { $0.offsetHorizontally(by: offset) }
    }

    func hideConversionPanels() {
        primaryCandidatePanel.hide()
        secondaryCandidatePanel.hide()
        hideTranslationCandidates()
        externalInformation.hide()
    }

    func dismissNextInputPresentation() {
        stopNextInputLifecycle()
        primaryCandidatePanel.hide()
        externalInformation.hide()
    }

    func dismiss(
        using policy: InputPanelDismissalPolicy,
        hidesSharedEmoji: Bool
    ) {
        stopNextInputLifecycle()
        for panel in policy.panelsToDismiss {
            switch panel {
            case .primaryCandidatePanel:
                primaryCandidatePanel.hide()
            case .secondaryCandidatePanel:
                secondaryCandidatePanel.hide()
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
            case .time:
                clearTimePresentation()
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
