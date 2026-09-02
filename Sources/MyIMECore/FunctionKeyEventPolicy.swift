public enum FunctionKeyEventPolicy {
    private static let ignoredKeyCodes: Set<UInt16> = [
        122, // F1
        120, // F2
        99,  // F3
        118, // F4
        96   // F5
    ]

    public static func shouldIgnore(keyCode: UInt16) -> Bool {
        ignoredKeyCodes.contains(keyCode)
    }
}
