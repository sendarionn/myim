import Testing
@testable import MyIMECore

@Suite
struct InputEscapeCommandActionTests {
    @Test
    func preservesTheExistingEscapePriority() {
        #expect(resolve(preview: true, emoji: true) == .closeEmoji)
        #expect(resolve(preview: true, calendar: true) == .closePreview)
        #expect(resolve(emoji: true, calendar: true) == .closeEmoji)
        #expect(resolve(calendar: true, calendarFormat: true) == .closeCalendar)
        #expect(resolve(time: true, timeFormat: true) == .closeTime)
        #expect(resolve(
            calendarFormat: true,
            translation: true
        ) == .cancelCalendarFormat)
        #expect(resolve(
            translation: true,
            state: .selectingFuzzyCandidate
        ) == .leaveTranslation)
        #expect(resolve(
            state: .selectingFuzzyCandidate,
            hasNextInput: true
        ) == .leaveFuzzyCandidate)
    }

    @Test(arguments: [
        InputInteractionState.composing,
        .selectingCandidate,
        .selectingNextInput
    ])
    func routesAnActiveStandardInteractionToCancellation(
        _ state: InputInteractionState
    ) {
        #expect(resolve(state: state) == .cancelStandardInput)
    }

    @Test
    func routesAnUnselectedNextInputPanelToCancellation() {
        #expect(resolve(hasNextInput: true) == .cancelStandardInput)
    }

    @Test
    func passesEscapeToTheApplicationWhileIdle() {
        #expect(resolve() == .passThrough)
    }

    private func resolve(
        preview: Bool = false,
        emoji: Bool = false,
        calendar: Bool = false,
        calendarFormat: Bool = false,
        time: Bool = false,
        timeFormat: Bool = false,
        translation: Bool = false,
        state: InputInteractionState = .idle,
        hasNextInput: Bool = false
    ) -> InputEscapeCommandAction {
        InputEscapeCommandAction.resolve(
            isPreviewActive: preview,
            isEmojiVisible: emoji,
            isCalendarVisible: calendar,
            isCalendarFormatSelecting: calendarFormat,
            isTimeVisible: time,
            isTimeFormatSelecting: timeFormat,
            isTranslationSelecting: translation,
            interactionState: state,
            hasNextInputCandidates: hasNextInput
        )
    }
}
