import Foundation

public enum NumericPrefixCandidateComposer {
    public struct Parts: Equatable, Sendable {
        public let number: String
        public let reading: String

        public init(number: String, reading: String) {
            self.number = number
            self.reading = reading
        }
    }

    public static func parts(of input: String) -> Parts? {
        guard let range = input.range(
            of: #"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)"#,
            options: .regularExpression
        ) else {
            return nil
        }
        let reading = String(input[range.upperBound...])
        guard !reading.isEmpty else { return nil }
        return Parts(number: String(input[range]), reading: reading)
    }

    public static func candidates(
        for input: String,
        convertedReadings: [String]
    ) -> [String] {
        guard let parts = parts(of: input) else { return [] }
        var seen = Set<String>()
        return convertedReadings.compactMap { converted in
            guard !converted.isEmpty else { return nil }
            let candidate = parts.number + converted
            return seen.insert(candidate).inserted ? candidate : nil
        }
    }
}
