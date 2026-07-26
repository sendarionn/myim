import AppKit
import InputMethodKit

private let bundleIdentifier = "io.github.sendarionn.my-ime"
private let connectionName = "\(bundleIdentifier).connection"

let application = NSApplication.shared
let server = IMKServer(
    name: connectionName,
    bundleIdentifier: bundleIdentifier
)

application.run()

withExtendedLifetime(server) {}
