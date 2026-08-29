import Foundation

public enum DictionaryCandidateRepresentation {
    private static let separator = "\t"

    public static func encoded(display: String, value: String) -> String? {
        guard !display.isEmpty, !value.isEmpty,
              !display.contains(separator), !value.contains(separator),
              !display.contains("\n"), !value.contains("\n")
        else { return nil }
        return display + separator + value
    }

    public static func display(from candidate: String) -> String {
        split(candidate)?.display ?? CandidateCommitNormalizer.value(from: candidate)
    }

    public static func value(from candidate: String) -> String {
        split(candidate)?.value ?? CandidateCommitNormalizer.value(from: candidate)
    }

    public static func normalizedForStorage(_ candidate: String) -> String {
        split(candidate) == nil
            ? CandidateCommitNormalizer.value(from: candidate)
            : candidate
    }

    private static func split(_ candidate: String) -> (display: String, value: String)? {
        guard let separatorIndex = candidate.firstIndex(of: "\t") else { return nil }
        let display = String(candidate[..<separatorIndex])
        let value = String(candidate[candidate.index(after: separatorIndex)...])
        guard !display.isEmpty, !value.isEmpty else { return nil }
        return (display, value)
    }
}
