import AppKit
import Carbon
import InputMethodKit

private let bundleIdentifier = "io.github.sendarionn.inputmethod.myime"
private let connectionName = "\(bundleIdentifier).connection"
private let inputSourceIdentifier = "\(bundleIdentifier).Japanese"

private func inputSource() -> TISInputSource? {
    let sources = TISCreateInputSourceList(nil, true).takeRetainedValue()
        as! [TISInputSource]
    return sources.first { source in
        guard let pointer = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else {
            return false
        }
        let identifier = Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue() as String
        return identifier == inputSourceIdentifier
    }
}

if CommandLine.arguments.contains("--register-input-source") {
    guard let bundleURL = Bundle.main.bundleURL as CFURL?,
          TISRegisterInputSource(bundleURL) == noErr else {
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

if CommandLine.arguments.contains("--enable-input-source") {
    guard let source = inputSource(),
          TISEnableInputSource(source) == noErr else {
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
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
