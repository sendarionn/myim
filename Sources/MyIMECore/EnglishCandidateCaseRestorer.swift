import Foundation

public enum EnglishCandidateCaseRestorer {
    public static func restore(
        typedInput: String,
        in candidate: String
    ) -> String {
        guard
            candidate.count >= typedInput.count,
            String(candidate.prefix(typedInput.count))
                .caseInsensitiveCompare(typedInput) == .orderedSame
        else {
            return candidate
        }

        return typedInput + candidate.dropFirst(typedInput.count)
    }
}
