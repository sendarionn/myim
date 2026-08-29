import Foundation

public enum DictionarySerializer {
    public static func text(from entries: [DictionaryEntry]) -> String {
        let lines = entries.flatMap { entry in
            entry.candidates.map { candidate in
                if let parts = DictionaryCandidateRepresentation.parts(
                    from: candidate
                ) {
                    return "\(entry.input)\t\(parts.display)\t\(parts.value)"
                }
                return "\(entry.input)\t\(candidate)"
            }
        }
        return lines.joined(separator: "\n")
            + (lines.isEmpty ? "" : "\n")
    }
}
