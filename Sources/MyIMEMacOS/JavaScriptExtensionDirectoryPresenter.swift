@preconcurrency import AppKit

enum JavaScriptExtensionDirectoryPresenter {
    static func open(_ directory: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            directory,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog(
                    "JavaScript拡張フォルダを開けません: %@",
                    error.localizedDescription
                )
            }
        }
    }
}
