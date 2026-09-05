import Foundation
import MyIMECore

actor JavaScriptExtensionClient {
    struct ExtensionInfo: Sendable {
        let fileName: String
        let prefix: String?
        let isEnabled: Bool
        let status: JavaScriptExtensionStatus?
    }

    private static let disabledFileNamesDefaultsKey =
        "DisabledJavaScriptExtensionFileNames"
    private static let executionTimeoutMilliseconds = 100
    private static let coldStartTimeoutMilliseconds = 2_000

    private struct PendingRequest {
        let continuation: CheckedContinuation<JavaScriptExtensionResponse?, Never>
        let timeout: Task<Void, Never>
    }

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputBuffer = Data()
    private var pending: [UUID: PendingRequest] = [:]
    private var latestStatuses: [String: JavaScriptExtensionStatus] = [:]
    private var latestRuntimeError: String?

    deinit {
        process?.terminate()
    }

    nonisolated static var userExtensionDirectory: URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("myim", isDirectory: true)
            .appendingPathComponent("Extensions", isDirectory: true)
    }

    @discardableResult
    nonisolated static func prepareUserExtensionDirectory() -> URL? {
        guard let user = userExtensionDirectory else { return nil }
        guard let builtIn = Bundle.main.resourceURL?
            .appendingPathComponent("Extensions", isDirectory: true) else {
            try? FileManager.default.createDirectory(
                at: user,
                withIntermediateDirectories: true
            )
            return user
        }
        do {
            try DefaultExtensionInstaller.installIfNeeded(
                from: builtIn,
                into: user
            )
        } catch {
            NSLog("標準JavaScript拡張の初期配置に失敗: %@", error.localizedDescription)
            try? FileManager.default.createDirectory(
                at: user,
                withIntermediateDirectories: true
            )
        }
        return user
    }

    nonisolated static func setEnabled(_ enabled: Bool, fileName: String) {
        var disabled = disabledFileNames
        if enabled {
            disabled.remove(fileName)
        } else {
            disabled.insert(fileName)
        }
        UserDefaults.standard.set(
            disabled.sorted(),
            forKey: disabledFileNamesDefaultsKey
        )
    }

    func extensionInfos() -> (items: [ExtensionInfo], runtimeError: String?) {
        guard let directory = Self.prepareUserExtensionDirectory() else {
            return ([], "拡張フォルダが見つかりません")
        }
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { $0.pathExtension.lowercased() == "js" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let disabled = Self.disabledFileNames
        let items = files.map { file -> ExtensionInfo in
            let source = try? String(contentsOf: file, encoding: .utf8)
            return ExtensionInfo(
                fileName: file.lastPathComponent,
                prefix: source.flatMap(Self.prefixMetadata),
                isEnabled: !disabled.contains(file.lastPathComponent),
                status: latestStatuses[file.lastPathComponent]
            )
        }
        return (items, latestRuntimeError)
    }

    func reload() {
        latestStatuses.removeAll()
        latestRuntimeError = nil
        stopHost()
    }

    func validateExtensions() async {
        _ = await candidates(
            for: "__myim_extension_status__",
            timestamp: Date(),
            settings: [
                "dateTimeCandidatesEnabled": ["true"]
            ]
        )
    }

    func candidates(
        for input: String,
        dateTimeCandidatesEnabled: Bool
    ) async -> [String] {
        await candidates(
            for: input,
            timestamp: Date(),
            settings: [
                "dateTimeCandidatesEnabled": [
                    dateTimeCandidatesEnabled ? "true" : "false"
                ],
                "dateFormats": dateTimeCandidatesEnabled
                    ? DateTimeCandidateGenerator.Formats.default.date : [],
                "timeFormats": dateTimeCandidatesEnabled
                    ? DateTimeCandidateGenerator.Formats.default.time : [],
                "dateTimeFormats": dateTimeCandidatesEnabled
                    ? DateTimeCandidateGenerator.Formats.default.dateTime : []
            ]
        )
    }

    func calendarCandidates(for date: Date) async -> [String] {
        await candidates(for: "calendar", timestamp: date, settings: [:])
    }

    private func candidates(
        for input: String,
        timestamp: Date,
        settings: [String: [String]]
    ) async -> [String] {
        guard !input.isEmpty else { return [] }
        let wasRunning = process?.isRunning == true
        guard startIfNeeded() else { return [] }
        let timeoutMilliseconds = wasRunning
            ? Self.executionTimeoutMilliseconds
            : Self.coldStartTimeoutMilliseconds
        let request = JavaScriptExtensionRequest(
            input: input,
            timestamp: ISO8601DateFormatter().string(from: timestamp),
            timeZone: TimeZone.current.identifier,
            extensionDirectories: Self.extensionDirectories,
            disabledFileNames: Self.disabledFileNames.sorted(),
            settings: settings
        )
        guard let data = try? JSONEncoder().encode(request) else { return [] }

        let response = await withCheckedContinuation { continuation in
            let timeout = Task { [weak self] in
                try? await Task.sleep(
                    for: .milliseconds(timeoutMilliseconds)
                )
                guard !Task.isCancelled else { return }
                await self?.timeout(request.id)
            }
            pending[request.id] = PendingRequest(
                continuation: continuation,
                timeout: timeout
            )
            do {
                try inputPipe?.fileHandleForWriting.write(contentsOf: data)
                try inputPipe?.fileHandleForWriting.write(contentsOf: Data([0x0A]))
            } catch {
                finish(request.id, response: nil)
                stopHost()
            }
        }
        if let response {
            latestStatuses = Dictionary(
                uniqueKeysWithValues: response.statuses.map { ($0.fileName, $0) }
            )
            latestRuntimeError = nil
            return response.candidates
        }
        return []
    }

    private func startIfNeeded() -> Bool {
        if process?.isRunning == true { return true }
        guard let executableURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers")
            .appendingPathComponent("myim-extension-host") as URL? else {
            return false
        }
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.executableURL = executableURL
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            Task { await self?.hostTerminated() }
        }
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.receive(data) }
        }
        do {
            try process.run()
            self.process = process
            self.inputPipe = inputPipe
            self.outputPipe = outputPipe
            return true
        } catch {
            return false
        }
    }

    private func receive(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newline]
            outputBuffer.removeSubrange(...newline)
            guard let response = try? JSONDecoder().decode(
                JavaScriptExtensionResponse.self,
                from: Data(line)
            ) else { continue }
            if !response.errors.isEmpty {
                NSLog("JavaScript拡張: %@", response.errors.joined(separator: " / "))
            }
            finish(response.id, response: response)
        }
    }

    private func timeout(_ id: UUID) {
        guard pending[id] != nil else { return }
        latestRuntimeError = "JavaScript拡張の実行が制限時間を超えました"
        finish(id, response: nil)
        stopHost()
    }

    private func finish(_ id: UUID, response: JavaScriptExtensionResponse?) {
        guard let request = pending.removeValue(forKey: id) else { return }
        request.timeout.cancel()
        request.continuation.resume(returning: response)
    }

    private func hostTerminated() {
        let requests = pending
        pending.removeAll()
        for request in requests.values {
            request.timeout.cancel()
            request.continuation.resume(returning: nil)
        }
        process = nil
        inputPipe = nil
        outputPipe = nil
        outputBuffer.removeAll(keepingCapacity: true)
    }

    private func stopHost() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
        outputBuffer.removeAll(keepingCapacity: true)
    }

    private static var extensionDirectories: [String] {
        if let user = prepareUserExtensionDirectory() {
            return [user.path]
        }
        return Bundle.main.resourceURL.map {
            [$0.appendingPathComponent("Extensions", isDirectory: true).path]
        } ?? []
    }

    private nonisolated static var disabledFileNames: Set<String> {
        Set(UserDefaults.standard.stringArray(
            forKey: disabledFileNamesDefaultsKey
        ) ?? [])
    }

    private nonisolated static func prefixMetadata(in source: String) -> String? {
        let marker = "// @myim-prefix "
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(20)
            .compactMap { line -> String? in
                let text = String(line)
                guard text.hasPrefix(marker) else { return nil }
                let value = String(text.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
            .first
    }
}
