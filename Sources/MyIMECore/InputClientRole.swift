public enum InputClientRole: Equatable, Sendable {
    case sourceApplication
    case auxiliaryApplication

    public static func resolve(bundleIdentifier: String?) -> Self {
        guard let bundleIdentifier else { return .sourceApplication }
        return auxiliaryBundleIdentifiers.contains(bundleIdentifier)
            ? .auxiliaryApplication
            : .sourceApplication
    }

    public var participatesInInputSessionLifecycle: Bool {
        self == .sourceApplication
    }

    private static let auxiliaryBundleIdentifiers: Set<String> = [
        "io.github.sendarionn.inputmethod.myime",
        "io.github.sendarionn.myim.external-browser"
    ]
}
