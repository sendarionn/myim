public enum ClosingBracketPanelUpdate: Equatable, Sendable {
    case unchanged
    case reposition
    case present(String)
    case dismiss

    public static func resolve(
        currentContext: String?,
        currentCandidates: [String],
        isPanelVisible: Bool,
        refreshedCandidate: String?
    ) -> Self {
        let isStructural = currentContext == "structuralClosingBracket"

        guard let refreshedCandidate else {
            return isStructural ? .dismiss : .unchanged
        }
        guard isStructural,
              currentCandidates == [refreshedCandidate] else {
            return .present(refreshedCandidate)
        }
        return isPanelVisible ? .reposition : .present(refreshedCandidate)
    }
}
