@preconcurrency import AppKit
import MyIMECore

final class ExternalBrowserBridge {
    private static let notificationName = Notification.Name(
        "io.github.sendarionn.myim.external-browser.command"
    )
    private var isLaunching = false
    private var pendingCommand: ExternalBrowserCommand?
    private var interactionObserver: NSObjectProtocol?
    var onInteractionBegan: (() -> Void)?

    init() {
        interactionObserver = DistributedNotificationCenter.default()
            .addObserver(
                forName: Notification.Name(
                    "io.github.sendarionn.myim.external-browser.interaction-began"
                ),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.onInteractionBegan?()
            }
    }

    deinit {
        if let interactionObserver {
            DistributedNotificationCenter.default().removeObserver(
                interactionObserver
            )
        }
    }

    func send(_ command: ExternalBrowserCommand) {
        guard let url = command.url else {
            writeAndNotify(command)
            return
        }
        guard url.scheme == "https" else {
            return
        }
        pendingCommand = command
        write(command)

        guard !isLaunching else {
            return
        }
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers")
            .appendingPathComponent("myim-external-browser.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = false
        isLaunching = true
        NSWorkspace.shared.openApplication(
            at: helperURL,
            configuration: configuration
        ) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.isLaunching = false
                if let error {
                    NSLog(
                        "外部情報ブラウザの起動に失敗: %@",
                        error.localizedDescription
                    )
                    return
                }
                if let pendingCommand = self.pendingCommand {
                    self.writeAndNotify(pendingCommand)
                    self.pendingCommand = nil
                }
            }
        }
    }

    func hide() {
        clearInteractionMarker()
        send(ExternalBrowserCommand(
            url: nil,
            title: "外部情報",
            frameX: 0,
            frameY: 0,
            frameWidth: 0,
            frameHeight: 0,
            isVisible: false
        ))
    }

    func hasRecentInteraction(maximumAge: TimeInterval = 2) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(
            atPath: Self.interactionMarkerURL().path
        ),
        let modifiedAt = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modifiedAt) <= maximumAge
    }

    func clearInteractionMarker() {
        try? FileManager.default.removeItem(at: Self.interactionMarkerURL())
    }

    private func writeAndNotify(_ command: ExternalBrowserCommand) {
        write(command)
        DistributedNotificationCenter.default().postNotificationName(
            Self.notificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func write(_ command: ExternalBrowserCommand) {
        do {
            let fileManager = FileManager.default
            let directory = try Self.commandFileURL()
                .deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(command)
            let file = try Self.commandFileURL()
            try data.write(to: file, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: file.path
            )
        } catch {
            NSLog("外部情報ブラウザへの指示保存に失敗: %@", error.localizedDescription)
        }
    }

    static func commandFileURL() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("myim/browser", isDirectory: true)
        .appendingPathComponent("command.json")
    }

    private static func interactionMarkerURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("myim/browser", isDirectory: true)
            .appendingPathComponent("interaction")
    }
}
