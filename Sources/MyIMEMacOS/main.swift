import AppKit
import InputMethodKit

private let bundleIdentifier = "io.github.sendarionn.inputmethod.myime"
private let connectionName = "\(bundleIdentifier)_Connection"

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
guard let server = IMKServer(
    name: connectionName,
    bundleIdentifier: bundleIdentifier
) else {
    NSLog("myim: IMKServer initialization failed bundle=%@ connection=%@", bundleIdentifier, connectionName)
    exit(EXIT_FAILURE)
}

NSLog("myim: IMKServer initialized bundle=%@ connection=%@", bundleIdentifier, connectionName)

withExtendedLifetime(server) {
    application.run()
}
