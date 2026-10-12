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
        case "--render-candidate-panel":
            let arguments = Array(CommandLine.arguments.dropFirst(2))
            guard arguments.count == 2 || arguments.count == 3,
                  let selectedIndex = Int(arguments.count == 3
                    ? arguments[2]
                    : "0") else {
                throw NSError(
                    domain: "myim.command",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        "使い方: myim --render-candidate-panel <入力> <出力.png> [選択位置]"]
                )
            }
            try InputController.renderCandidatePanelImage(
                input: arguments[0],
                selectedIndex: selectedIndex,
                to: URL(fileURLWithPath: arguments[1])
            )
        case "--render-readme-demo":
            let arguments = Array(CommandLine.arguments.dropFirst(2))
            guard arguments.count == 2 else {
                throw NSError(
                    domain: "myim.command",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        "使い方: myim --render-readme-demo <シナリオ> <出力.gif>"]
                )
            }
            try MainActor.assumeIsolated {
                try ReadmeDemoRenderer.render(
                    scenario: arguments[0],
                    to: URL(fileURLWithPath: arguments[1])
                )
            }
        case "--install-default-extensions":
            guard JavaScriptExtensionClient.prepareUserExtensionDirectory()
                != nil else {
                throw NSError(
                    domain: "myim.command",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "標準JavaScript拡張を配置できません"
                    ]
                )
            }
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
