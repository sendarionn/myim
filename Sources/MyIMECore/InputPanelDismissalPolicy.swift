public enum InputPanelKind: String, CaseIterable, Hashable, Sendable {
    case primaryCandidatePanel
    case secondaryCandidatePanel
    case translationCandidates
    case emoji
    case externalInformation
    case symbolTips
    case candidateFilterDraft
    case candidateFilterConditions
    case calendar
    case time
}

public struct InputPanelDismissalPolicy: Equatable, Sendable {
    public let preservesExternalInformation: Bool
    public let preservesCalendar: Bool
    public let preservesTime: Bool
    public let preservesEmoji: Bool

    public init(
        preservesExternalInformation: Bool,
        preservesCalendar: Bool,
        preservesTime: Bool = false,
        preservesEmoji: Bool = false
    ) {
        self.preservesExternalInformation = preservesExternalInformation
        self.preservesCalendar = preservesCalendar
        self.preservesTime = preservesTime
        self.preservesEmoji = preservesEmoji
    }

    public static let inputBecameEmpty = InputPanelDismissalPolicy(
        preservesExternalInformation: false,
        preservesCalendar: false
    )

    /// Clearing the emoji search returns the panel to its initial emojis
    /// instead of closing it
    public static let emojiSearchBecameEmpty = InputPanelDismissalPolicy(
        preservesExternalInformation: false,
        preservesCalendar: false,
        preservesEmoji: true
    )

    public var cancelsCalendarWork: Bool {
        !preservesCalendar
    }

    public var cancelsTimeWork: Bool { !preservesTime }

    public var panelsToDismiss: Set<InputPanelKind> {
        var panels = Set(InputPanelKind.allCases)
        if preservesExternalInformation {
            panels.remove(.externalInformation)
        }
        if preservesCalendar {
            panels.remove(.primaryCandidatePanel)
            panels.remove(.calendar)
        }
        if preservesTime {
            panels.remove(.primaryCandidatePanel)
            panels.remove(.time)
        }
        if preservesEmoji {
            panels.remove(.emoji)
        }
        return panels
    }

    public static func deactivation(
        isExternalInformationInteractionActive: Bool,
        isCalendarInteractionActive: Bool,
        isTimeInteractionActive: Bool = false
    ) -> InputPanelDismissalPolicy {
        InputPanelDismissalPolicy(
            preservesExternalInformation: isExternalInformationInteractionActive,
            preservesCalendar: isCalendarInteractionActive,
            preservesTime: isTimeInteractionActive
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
