import Foundation
import MyIMECore

actor JavaScriptExtensionClient {
    private struct PendingRequest {
        let continuation: CheckedContinuation<[String], Never>
        let timeout: Task<Void, Never>
    }

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputBuffer = Data()
    private var pending: [UUID: PendingRequest] = [:]

    deinit {
        process?.terminate()
    }

    func candidates(
        for input: String,
        dateFormats: [String],
        timeFormats: [String],
        dateTimeFormats: [String]
    ) async -> [String] {
        guard !input.isEmpty, startIfNeeded() else { return [] }
        let request = JavaScriptExtensionRequest(
            input: input,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            timeZone: TimeZone.current.identifier,
            extensionDirectories: Self.extensionDirectories,
            settings: [
                "dateFormats": dateFormats,
                "timeFormats": timeFormats,
                "dateTimeFormats": dateTimeFormats
            ]
        )
        guard let data = try? JSONEncoder().encode(request) else { return [] }

        return await withCheckedContinuation { continuation in
            let timeout = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
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
                finish(request.id, candidates: [])
                stopHost()
            }
        }
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
            finish(response.id, candidates: response.candidates)
        }
    }

    private func timeout(_ id: UUID) {
        guard pending[id] != nil else { return }
        finish(id, candidates: [])
        stopHost()
    }

    private func finish(_ id: UUID, candidates: [String]) {
        guard let request = pending.removeValue(forKey: id) else { return }
        request.timeout.cancel()
        request.continuation.resume(returning: candidates)
    }

    private func hostTerminated() {
        let requests = pending
        pending.removeAll()
        for request in requests.values {
            request.timeout.cancel()
            request.continuation.resume(returning: [])
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
        var directories: [String] = []
        if let builtIn = Bundle.main.resourceURL?
            .appendingPathComponent("Extensions", isDirectory: true) {
            directories.append(builtIn.path)
        }
        if let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            let user = support
                .appendingPathComponent("myim", isDirectory: true)
                .appendingPathComponent("Extensions", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: user,
                withIntermediateDirectories: true
            )
            directories.append(user.path)
        }
        return directories
    }
}
