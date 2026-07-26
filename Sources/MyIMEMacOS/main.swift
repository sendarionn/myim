import AppKit
import InputMethodKit

private let bundleIdentifier = "io.github.sendarionn.inputmethod.myime"
private let connectionName = "\(bundleIdentifier)_Connection"

let application = NSApplication.shared
let server = IMKServer(
    name: connectionName,
    bundleIdentifier: bundleIdentifier
)

application.run()

withExtendedLifetime(server) {}
