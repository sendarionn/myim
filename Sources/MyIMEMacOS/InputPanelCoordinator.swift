@preconcurrency import AppKit
import MyIMECore

final class InputPanelCoordinator {
    let candidate = CandidateWindowController()
    let candidateFilterDraft = CandidateWindowController()
    var candidateFilterConditions: [CandidateWindowController] = []
    let calendar = CalendarWindowController()
    let emoji = EmojiWindowController.shared
    let fuzzySuggestion = FuzzySuggestionWindowController()
    let translationCandidate = CandidateWindowController()
    let externalInformation = ExternalInformationWindowController()
    let symbolTips = SymbolTipsWindowController()

    func dismiss(using policy: InputPanelDismissalPolicy) {
        if policy.cancelsCalendarWork {
            candidate.hide()
        }
        fuzzySuggestion.hide()
        emoji.hide()
        symbolTips.hide()
        candidateFilterDraft.hide()
        candidateFilterConditions.forEach { $0.hide() }
        candidateFilterConditions.removeAll(keepingCapacity: true)
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
        candidateFilterConditions.forEach { $0.hide() }
        candidateFilterConditions.removeAll(keepingCapacity: true)
        calendar.hide()
    }
}
