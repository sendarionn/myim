public enum InputEscapeCommandAction: Equatable, Sendable {
    case closePreview
    case closeEmoji
    case closeCalendar
    case cancelCalendarFormat
    case closeTime
    case cancelTimeFormat
    case leaveTranslation
    case leaveFuzzyCandidate
    case cancelStandardInput
    case passThrough

    public static func resolve(
        isPreviewActive: Bool,
        isEmojiVisible: Bool,
        isCalendarVisible: Bool,
        isCalendarFormatSelecting: Bool,
        isTimeVisible: Bool,
        isTimeFormatSelecting: Bool,
        isTranslationSelecting: Bool,
        interactionState: InputInteractionState,
        hasNextInputCandidates: Bool
    ) -> Self {
        if isEmojiVisible { return .closeEmoji }
        if isPreviewActive { return .closePreview }
        if isCalendarVisible { return .closeCalendar }
        if isCalendarFormatSelecting { return .cancelCalendarFormat }
        if isTimeVisible { return .closeTime }
        if isTimeFormatSelecting { return .cancelTimeFormat }
        if isTranslationSelecting { return .leaveTranslation }
        if interactionState == .selectingFuzzyCandidate {
            return .leaveFuzzyCandidate
        }
        if hasNextInputCandidates
            || interactionState == .composing
            || interactionState == .selectingCandidate
            || interactionState == .selectingNextInput {
            return .cancelStandardInput
        }
        return .passThrough
    }
}
