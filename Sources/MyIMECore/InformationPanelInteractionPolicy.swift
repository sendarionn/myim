public enum InformationPanelInteractionPolicy {
    public static func shouldBeginInteraction(
        isPresentingInformation: Bool,
        frontmostClientRole: InputClientRole
    ) -> Bool {
        isPresentingInformation
            && frontmostClientRole == .auxiliaryApplication
    }
}
