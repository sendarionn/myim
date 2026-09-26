public enum EmptyInputModeStatusPolicy {
    public static func shouldShow(
        isModeActive: Bool,
        isInputEmpty: Bool,
        isBusy: Bool = false,
        hasPresentedResults: Bool = false
    ) -> Bool {
        isModeActive && isInputEmpty && !isBusy && !hasPresentedResults
    }
}
