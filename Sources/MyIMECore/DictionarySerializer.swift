import Foundation

public enum DictionarySerializer {
    public static func text(from entries: [DictionaryEntry]) -> String {
        entries.map { entry in
            ([entry.reading] + entry.candidates.map { " \($0)" })
                .joined(separator: "\n")
        }
        .joined(separator: "\n\n") + (entries.isEmpty ? "" : "\n")
    }
}
