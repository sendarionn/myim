import Foundation

public enum EnglishCandidateCaseRestorer {
    public static func initialUppercaseCandidate(
        for input: String
    ) -> String? {
        guard isASCIILettersOnly(input),
              let first = input.first else {
            return nil
        }
        let candidate = String(first).uppercased() + input.dropFirst()
        return candidate == input ? nil : candidate
    }

    public static func uppercaseCandidate(for input: String) -> String? {
        guard isASCIILettersOnly(input) else {
            return nil
        }
        let uppercase = input.uppercased()
        return uppercase == input ? nil : uppercase
    }

    public static func caseCandidates(for input: String) -> [String] {
        [
            initialUppercaseCandidate(for: input),
            uppercaseCandidate(for: input)
        ]
        .compactMap { $0 }
        .reduce(into: []) { candidates, candidate in
            if !candidates.contains(candidate) {
                candidates.append(candidate)
            }
        }
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

    private static func isASCIILettersOnly(_ input: String) -> Bool {
        !input.isEmpty && input.unicodeScalars.allSatisfy {
            $0.isASCII && CharacterSet.letters.contains($0)
        }
    }
}
