import Foundation

public enum ExternalBrowserCommandDelivery: Equatable, Sendable {
    case notifyRunningHelper
    case launchHelper
    case waitForLaunch
    case discard

    /// Re-opening the running helper through LaunchServices can make it the
    /// front process even when activation is disabled, which deactivates the
    /// input client and commits its composition, so a running helper is only
    /// notified
    public static func resolve(
        url: URL?,
        isHelperRunning: Bool,
        isLaunching: Bool
    ) -> Self {
        guard let url else { return .notifyRunningHelper }
        guard url.scheme == "https" else { return .discard }
        if isLaunching { return .waitForLaunch }
        return isHelperRunning ? .notifyRunningHelper : .launchHelper
    }
}
