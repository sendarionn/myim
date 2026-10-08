public enum InputPanelKind: String, CaseIterable, Hashable, Sendable {
    case candidate
    case fuzzySuggestion
    case translationCandidates
    case emoji
    case externalInformation
    case symbolTips
    case candidateFilterDraft
    case candidateFilterConditions
    case calendar
}

public struct InputPanelDismissalPolicy: Equatable, Sendable {
    public let preservesExternalInformation: Bool
    public let preservesCalendar: Bool

    public static let inputBecameEmpty = InputPanelDismissalPolicy(
        preservesExternalInformation: false,
        preservesCalendar: false
    )

    public var cancelsCalendarWork: Bool {
        !preservesCalendar
    }

    public var panelsToDismiss: Set<InputPanelKind> {
        var panels = Set(InputPanelKind.allCases)
        if preservesExternalInformation {
            panels.remove(.externalInformation)
        }
        if preservesCalendar {
            panels.remove(.candidate)
            panels.remove(.calendar)
        }
        return panels
    }

    public static func deactivation(
        isExternalInformationInteractionActive: Bool,
        isCalendarInteractionActive: Bool
    ) -> InputPanelDismissalPolicy {
        InputPanelDismissalPolicy(
            preservesExternalInformation: isExternalInformationInteractionActive,
            preservesCalendar: isCalendarInteractionActive
        )
    }
}

public enum SharedPanelDismissalPolicy {
    public static func shouldDismiss(
        ownerID: String?,
        requestingControllerID: String
    ) -> Bool {
        ownerID == nil || ownerID == requestingControllerID
    }
}
