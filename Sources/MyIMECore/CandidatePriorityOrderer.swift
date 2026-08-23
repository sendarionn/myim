public enum CandidatePriorityOrderer {
    public static func ordered(
        kana: [String],
        direct: [String],
        others: [String],
        recencyRanks: [String: Int],
        contextualCandidates: [String] = [],
        prioritizeKana: Bool
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(kana.count + direct.count + others.count)

        func appendUnique(_ candidates: [String]) {
            for candidate in candidates where seen.insert(candidate).inserted {
                result.append(candidate)
            }
        }

        func orderedByContext(_ candidates: [String]) -> [String] {
            let recencyOrdered = CandidateRecencyOrderer.ordered(
                candidates,
                ranks: recencyRanks
            )
            let available = Set(recencyOrdered)
            var contextual = Set<String>()
            let preferred = contextualCandidates.filter {
                available.contains($0) && contextual.insert($0).inserted
            }
            return preferred + recencyOrdered.filter {
                !contextual.contains($0)
            }
        }

        if prioritizeKana {
            appendUnique(kana)
            let contextualSet = Set(contextualCandidates)
            appendUnique(orderedByContext(
                (direct + others).filter { contextualSet.contains($0) }
            ))
            appendUnique(CandidateRecencyOrderer.ordered(
                direct.filter { !seen.contains($0) },
                ranks: recencyRanks
            ))
            appendUnique(CandidateRecencyOrderer.ordered(
                others.filter { !seen.contains($0) },
                ranks: recencyRanks
            ))
            return result
        }

        appendUnique(orderedByContext(
            direct + kana + others
        ))
        return result
    }
}
