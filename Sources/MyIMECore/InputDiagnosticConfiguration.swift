import Foundation

public enum InputDiagnosticFeature: String, CaseIterable, Sendable {
    case dictionaryPanel
    case externalInformationPanel
    case translation
    case fuzzySuggestion
    case nextInput
    case jsExtensions
    case learning
}

public struct InputDiagnosticConfiguration: Equatable, Sendable {
    public let traceEnabled: Bool
    public let minimalMode: Bool
    public let disabledFeatures: Set<InputDiagnosticFeature>
    public let hiddenPanels: Set<InputDiagnosticFeature>

    public init(environment: [String: String]) {
        traceEnabled = environment["MYIM_SESSION_TRACE"] != "0"
        minimalMode = environment["MYIM_DIAGNOSTIC_MINIMAL"] == "1"
        disabledFeatures = Self.features(
            in: environment["MYIM_DIAGNOSTIC_DISABLE"]
        )
        hiddenPanels = Self.features(
            in: environment["MYIM_DIAGNOSTIC_HIDE_PANELS"]
        )
    }

    public func enables(_ feature: InputDiagnosticFeature) -> Bool {
        if minimalMode {
            return false
        }
        return !disabledFeatures.contains(feature)
    }

    public func presentsPanel(_ feature: InputDiagnosticFeature) -> Bool {
        enables(feature) && !hiddenPanels.contains(feature)
    }

    private static func features(
        in value: String?
    ) -> Set<InputDiagnosticFeature> {
        Set((value ?? "").split(separator: ",").compactMap {
            InputDiagnosticFeature(rawValue: String($0))
        })
    }
}
