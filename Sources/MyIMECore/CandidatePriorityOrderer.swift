public enum CandidatePriorityOrderer {
    public static func ordered(
        kana: [String],
        direct: [String],
        others: [String],
        recencyRanks: [String: Int]
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(kana.count + direct.count + others.count)

        func appendUnique(_ candidates: [String]) {
            for candidate in candidates where seen.insert(candidate).inserted {
                result.append(candidate)
            }
        }

        appendUnique(kana)
        appendUnique(direct)
        appendUnique(CandidateRecencyOrderer.ordered(
            others.filter { !seen.contains($0) },
            ranks: recencyRanks
        ))
        return result
    }
}
