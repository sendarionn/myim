@preconcurrency import AppKit

final class CosenseLoginWindowController {
    func show(project: String) {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers")
            .appendingPathComponent("myim-cosense-login.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(
            at: helperURL,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog(
                    "Cosenseログイン補助アプリの起動に失敗: %@",
                    error.localizedDescription
                )
                NSSound.beep()
            }
        }
    }
}
