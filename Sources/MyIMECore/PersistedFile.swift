import Foundation

/// A user data file read at launch. A file that exists but cannot be read
/// or decoded is not the same as no data: it is copied aside before the
/// caller starts empty, so the next save does not replace it unseen
public enum PersistedFile {
    public enum Load<Value> {
        case missing
        case loaded(Value)
        /// Where the unreadable file was copied, if copying succeeded
        case unreadable(preservedAt: URL?)
    }

    public static func load<Value>(
        from url: URL,
        fileManager: FileManager = .default,
        now: Date = Date(),
        decode: (Data) -> Value?
    ) -> Load<Value> {
        guard fileManager.fileExists(atPath: url.path) else { return .missing }
        if let data = try? Data(contentsOf: url) {
            if data.isEmpty { return .missing }
            if let value = decode(data) { return .loaded(value) }
        }
        return .unreadable(preservedAt: preserve(url, fileManager: fileManager, now: now))
    }

    private static func preserve(_ url: URL, fileManager: FileManager, now: Date) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let copy = url.deletingPathExtension()
            .appendingPathExtension("unreadable-\(formatter.string(from: now))")
            .appendingPathExtension(url.pathExtension)
        do {
            if fileManager.fileExists(atPath: copy.path) {
                return copy
            }
            try fileManager.copyItem(at: url, to: copy)
            return copy
        } catch {
            return nil
        }
    }
}
