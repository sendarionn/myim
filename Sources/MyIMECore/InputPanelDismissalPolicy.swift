public struct InputPanelDismissalPolicy: Equatable, Sendable {
    public let preservesExternalInformation: Bool
    public let preservesCalendar: Bool

    public static let inputBecameEmpty = InputPanelDismissalPolicy(
        preservesExternalInformation: false,
        preservesCalendar: false
    )

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
