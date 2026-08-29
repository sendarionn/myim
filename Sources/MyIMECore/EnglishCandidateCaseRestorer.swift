import Foundation

public enum EnglishCandidateCaseRestorer {
    public static func uppercaseCandidate(for input: String) -> String? {
        guard !input.isEmpty,
              input.unicodeScalars.allSatisfy({
                  $0.isASCII && CharacterSet.letters.contains($0)
              }) else {
            return nil
        }
        let uppercase = input.uppercased()
        return uppercase == input ? nil : uppercase
    }

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
