import AppKit
import InputMethodKit

private let bundleIdentifier = "io.github.sendarionn.inputmethod.myime"
private let connectionName = "\(bundleIdentifier).connection"

if let command = CommandLine.arguments.dropFirst().first {
    do {
        switch command {
        case "--input-source-status":
            print("registered=\(InputSourceRegistrationManager.isRegistered ? 1 : 0)")
            print("enabled=\(InputSourceRegistrationManager.isEnabled ? 1 : 0)")
            print("selected=\(InputSourceRegistrationManager.isSelected ? 1 : 0)")
            print("fallback-selected=\(InputSourceRegistrationManager.isFallbackSelected ? 1 : 0)")
        case "--register-input-source":
            try InputSourceRegistrationManager.register(
                bundleURL: Bundle.main.bundleURL
            )
        case "--enable-input-source":
            try InputSourceRegistrationManager.enableMyIM()
        case "--select-input-source":
            try InputSourceRegistrationManager.selectMyIM()
        case "--select-fallback-input-source":
            try InputSourceRegistrationManager.selectFallback()
        default:
            throw NSError(
                domain: "myim.command",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "不明なコマンド: \(command)"]
            )
        }
        exit(EXIT_SUCCESS)
    } catch {
        fputs("myim: \(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

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
