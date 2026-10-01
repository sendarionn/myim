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
            calendar.hide()
        }
    }

    func dismissAll() {
        candidate.hide()
        fuzzySuggestion.hide()
        translationCandidate.hide()
        emoji.hide()
        externalInformation.hide()
        symbolTips.hide()
        candidateFilterDraft.hide()
        hideFilterConditions()
        calendar.hide()
    }
}
