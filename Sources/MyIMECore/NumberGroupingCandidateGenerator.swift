public enum NumberGroupingCandidateGenerator {
    public static func candidates(for input: String) -> [String] {
        guard !input.isEmpty else { return [] }
        let sign: Substring
        let unsigned: Substring
        if input.first == "+" || input.first == "-" {
            sign = input.prefix(1)
            unsigned = input.dropFirst()
        } else {
            sign = ""
            unsigned = Substring(input)
        }

        let parts = unsigned.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard parts.count <= 2,
              let integer = parts.first,
              integer.count >= 4,
              integer.allSatisfy({ $0.isASCII && $0.isNumber }),
              parts.dropFirst().allSatisfy({
                  !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber }
              }) else {
            return []
        }

        let reversed = integer.reversed()
        var groupedReversed: [Character] = []
        groupedReversed.reserveCapacity(integer.count + integer.count / 3)
        for (index, digit) in reversed.enumerated() {
            if index > 0, index.isMultiple(of: 3) {
                groupedReversed.append(",")
            }
            groupedReversed.append(digit)
        }
        var grouped = String(sign) + String(groupedReversed.reversed())
        if parts.count == 2 {
            grouped += "." + parts[1]
        }
        return [grouped]
    }
}
