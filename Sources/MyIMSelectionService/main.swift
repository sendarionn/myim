import AppKit
import MyIMECore
import os

private final class SelectionServiceProvider: NSObject {
    private static let legacyStringType = NSPasteboard.PasteboardType(
        "NSStringPboardType"
    )
    private static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "selection-service"
    )

    @objc
    func captureSelection(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let receivedText = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: Self.legacyStringType)
        guard let text = SelectionServiceText.received(receivedText) else {
            Self.logger.error(
                "capture failed stage=service-pasteboard reason=no-text"
            )
            error.pointee = "選択文字列を取得できません" as NSString
            return
        }

        Self.logger.notice(
            "capture succeeded source=macos-service length=\(text.count, privacy: .public)"
        )
        NSSound(named: "Tink")?.play()
    }
}

private let portName = "myim-selection-service"
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
private let provider = SelectionServiceProvider()
NSRegisterServicesProvider(provider, portName)

withExtendedLifetime(provider) {
    application.run()
}
