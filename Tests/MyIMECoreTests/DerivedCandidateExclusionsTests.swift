import Foundation
import Testing
@testable import MyIMECore

@Suite
struct DerivedCandidateExclusionsTests {
    private let base = InflectionBaseIdentity(
        kind: .verb, reading: "kentousuru", surface: "検討する", inflectionType: "suru"
    )

    /// 検討した made from 検討する registered is a derived candidate; one made
    /// from a word not registered is not
    @Test
    func candidatesMadeFromRegisteredWordsAreDerived() {
        let shita = Candidate(storageText: "検討した", source: .verbInflection, inflectionBase: base)
        let registered = [DictionaryEntry(input: "kentousuru", candidates: ["検討する"])]
        #expect(DerivedCandidateOrigin.isDerived(shita, fromUserEntries: registered))
        #expect(!DerivedCandidateOrigin.isDerived(shita, fromUserEntries: []))
        #expect(!DerivedCandidateOrigin.isDerived(
            Candidate(storageText: "検討", source: .systemDictionary),
            fromUserEntries: registered
        ))
    }

    /// Only the removed text of the reading goes; other inflections, the
    /// same text of another reading, and a word registered again stay
    @Test
    func onlyTheRemovedCandidateOfTheReadingIsLeftOut() throws {
        var exclusions = DerivedCandidateExclusions()
        exclusions.insert(reading: "kentoushita", candidate: "検討した")
        let candidates = ["検討した", "健闘した", "見当した"].map { Candidate(storageText: $0) }
        #expect(exclusions.filtering(candidates, reading: "kentoushita").map(\.storageText)
            == ["健闘した", "見当した"])
        #expect(exclusions.filtering(candidates, reading: "kenntoushita").count == 3)
        // Kept across launches
        let saved = try JSONDecoder().decode(
            DerivedCandidateExclusions.self,
            from: JSONEncoder().encode(exclusions)
        )
        #expect(saved.contains(reading: "kentoushita", candidate: "検討した"))
        exclusions.remove(reading: "kentoushita", candidate: "検討した")
        #expect(exclusions.isEmpty)
    }
}
