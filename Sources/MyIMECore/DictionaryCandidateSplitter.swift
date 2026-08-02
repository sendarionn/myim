import Foundation

public enum DictionaryCandidateSplitter {
    public static func alternatives(from value: String) -> [String] {
        let parts = value
            .split(whereSeparator: { $0 == "/" || $0 == "／" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.count >= 2 ? parts : [value]
    }
}
