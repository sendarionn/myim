public enum InputTraceClientRangePolicy {
    public static func shouldCapture(for event: String) -> Bool {
        switch event {
        case "InputController.created",
             "InputController.willClose",
             "activateServer",
             "deactivateServer",
             "commitComposition.request",
             "commitComposition.execute",
             "cancelComposition",
             "setMarkedText.complete",
             "insertText.request",
             "insertText.complete":
            true
        default:
            false
        }
    }
}
