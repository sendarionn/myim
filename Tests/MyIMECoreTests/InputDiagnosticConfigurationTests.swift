import Testing
@testable import MyIMECore

@Suite struct InputDiagnosticConfigurationTests {
    @Test func enablesSessionTraceByDefault() {
        let configuration = InputDiagnosticConfiguration(environment: [:])

        #expect(configuration.traceEnabled)
    }

    @Test func allowsSessionTraceToBeDisabledExplicitly() {
        let configuration = InputDiagnosticConfiguration(environment: [
            "MYIM_SESSION_TRACE": "0"
        ])

        #expect(!configuration.traceEnabled)
    }

    @Test func disablesFeaturesIndependently() {
        let configuration = InputDiagnosticConfiguration(environment: [
            "MYIM_DIAGNOSTIC_DISABLE": "dictionaryPanel,translation"
        ])

        #expect(!configuration.enables(.dictionaryPanel))
        #expect(configuration.enables(.externalInformationPanel))
        #expect(!configuration.enables(.translation))
    }

    @Test func canRunLookupWithoutPresentingItsPanel() {
        let configuration = InputDiagnosticConfiguration(environment: [
            "MYIM_DIAGNOSTIC_HIDE_PANELS":
                "dictionaryPanel,externalInformationPanel"
        ])

        #expect(configuration.enables(.dictionaryPanel))
        #expect(!configuration.presentsPanel(.dictionaryPanel))
        #expect(configuration.enables(.externalInformationPanel))
        #expect(!configuration.presentsPanel(.externalInformationPanel))
    }

    @Test func minimalModeDisablesEveryOptionalFeature() {
        let configuration = InputDiagnosticConfiguration(environment: [
            "MYIM_DIAGNOSTIC_MINIMAL": "1"
        ])

        for feature in InputDiagnosticFeature.allCases {
            #expect(!configuration.enables(feature))
        }
    }
}
