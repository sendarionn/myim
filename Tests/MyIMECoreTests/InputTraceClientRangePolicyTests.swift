import Testing
@testable import MyIMECore

@Suite
struct InputTraceClientRangePolicyTests {
    @Test
    func capturesRangesAtCompositionBoundaries() {
        for event in [
            "activateServer", "deactivateServer",
            "commitComposition.request", "setMarkedText.complete",
            "insertText.request", "insertText.complete"
        ] {
            #expect(InputTraceClientRangePolicy.shouldCapture(for: event))
        }
    }

    @Test
    func reusesRangesForHighFrequencyDiagnosticEvents() {
        for event in [
            "keyDown", "candidateGeneration.start",
            "candidateGeneration.complete", "candidateSelection.changed"
        ] {
            #expect(!InputTraceClientRangePolicy.shouldCapture(for: event))
        }
    }
}
