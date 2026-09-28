public enum InputControllerClosurePolicy {
    public static func shouldCommitComposition(
        deactivationWasPending: Bool,
        sessionWasSuperseded: Bool
    ) -> Bool {
        deactivationWasPending && !sessionWasSuperseded
    }
}
