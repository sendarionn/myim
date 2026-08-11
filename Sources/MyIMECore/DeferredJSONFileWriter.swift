import Foundation

public final class DeferredJSONFileWriter<Value: Encodable & Sendable>:
    @unchecked Sendable {
    private let fileURL: URL
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private let errorHandler: @Sendable (Error) -> Void
    private let lock = NSLock()
    private var pendingValue: Value?
    private var pendingID: UUID?
    private var pendingWorkItem: DispatchWorkItem?

    public init(
        fileURL: URL,
        delay: TimeInterval = 0.4,
        queueLabel: String,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.fileURL = fileURL
        self.delay = max(0, delay)
        self.queue = DispatchQueue(label: queueLabel, qos: .utility)
        self.errorHandler = errorHandler
    }

    public func schedule(_ value: Value) {
        let id = UUID()
        let workItem = DispatchWorkItem { [weak self] in
            self?.writePendingValue(id: id)
        }
        lock.lock()
        pendingValue = value
        pendingID = id
        pendingWorkItem?.cancel()
        pendingWorkItem = workItem
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    public func writeImmediately(_ value: Value) throws {
        let pendingWorkItem = takePendingWorkItem()
        pendingWorkItem?.cancel()
        try queue.sync {
            try persist(value)
        }
    }

    public func flush() {
        let value = takePendingValue()
        guard let value else {
            queue.sync {}
            return
        }
        queue.sync {
            write(value)
        }
    }

    private func writePendingValue(id: UUID) {
        guard let value = takePendingValue(id: id) else {
            return
        }
        write(value)
    }

    private func takePendingValue() -> Value? {
        lock.lock()
        defer { lock.unlock() }
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        pendingID = nil
        defer { pendingValue = nil }
        return pendingValue
    }

    private func takePendingValue(id: UUID) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard pendingID == id else {
            return nil
        }
        pendingWorkItem = nil
        pendingID = nil
        defer { pendingValue = nil }
        return pendingValue
    }

    private func takePendingWorkItem() -> DispatchWorkItem? {
        lock.lock()
        defer { lock.unlock() }
        defer {
            pendingWorkItem = nil
            pendingID = nil
            pendingValue = nil
        }
        return pendingWorkItem
    }

    private func write(_ value: Value) {
        do {
            try persist(value)
        } catch {
            errorHandler(error)
        }
    }

    private func persist(_ value: Value) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try JSONEncoder().encode(value).write(
            to: fileURL,
            options: .atomic
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
