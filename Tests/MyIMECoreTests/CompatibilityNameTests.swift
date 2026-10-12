import Foundation
import Testing
@testable import MyIMECore

/// Code names follow the candidate vocabulary while saved data and
/// external switches keep the values written by earlier versions
@Suite
struct CompatibilityNameTests {
    @Test
    func fuzzyCandidateSettingIsReadFromTheSavedKey() throws {
        let suite = "myim.compatibility.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "FuzzySuggestionsEnabled")

        #expect(InputFeatureSettings(defaults: defaults)
            .isFuzzyCandidatesEnabled)
    }

    @Test
    func diagnosticSwitchKeepsItsEnvironmentValue() {
        let configuration = InputDiagnosticConfiguration(
            environment: ["MYIM_DIAGNOSTIC_DISABLE": "fuzzySuggestion"]
        )

        #expect(!configuration.enables(.fuzzyCandidate))
    }

    @Test
    func acceptedCandidatesAreSavedWithTheirFormerNames() throws {
        var model = NextInputPredictionModel()
        for _ in 0..<2 {
            model.record("実装")
            model.record("に", source: .acceptedCandidate)
            model.record("進んで", source: .acceptedCandidate)
            model.breakSequence()
        }
        model.record("実装")
        model.record("に", source: .acceptedCandidate)

        let saved = String(
            decoding: try JSONEncoder().encode(model),
            as: UTF8.self
        )
        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: Data(saved.utf8)
        )

        #expect(saved.contains("\"acceptedSuggestion\""))
        #expect(saved.contains("\"acceptedSuggestionCount\""))
        #expect(restored.candidates(after: "実装", limit: 16)
            .contains("に進んで"))
    }
}
