import Foundation
import Testing
@testable import MyIMECore

@Suite
struct DerivedCandidateOriginTests {
    private let registered = [
        DictionaryEntry(input: "kentousuru", candidates: ["検討する"]),
        DictionaryEntry(input: "kenntousuru", candidates: ["検討する"]),
        DictionaryEntry(input: "watashi", candidates: ["私"])
    ]

    /// 検討した made from 検討する is traced to the registration of that
    /// reading only, not to 検討する registered under another reading
    @Test
    func anInflectionIsTracedToTheRegistrationOfItsBase() {
        let shita = Candidate(
            storageText: "検討した",
            source: .verbInflection,
            inflectionBase: InflectionBaseIdentity(
                kind: .verb, reading: "kentousuru", surface: "検討する", inflectionType: "suru"
            )
        )
        #expect(DerivedCandidateOrigin.sourceEntries(of: shita, in: registered)
            == [.init(reading: "kentousuru", candidate: "検討する")])
    }

    /// A composition is traced through the word before its particle
    @Test
    func aCompositionIsTracedThroughItsWord() {
        let watashiha = Candidate(
            storageText: "私は",
            source: .particleComposition,
            baseWords: [CandidateBaseWord(reading: "watashi", surface: "私")]
        )
        #expect(DerivedCandidateOrigin.sourceEntries(of: watashiha, in: registered)
            == [.init(reading: "watashi", candidate: "私")])
    }

    /// Text alone traces nothing, nor a word nobody registered
    @Test
    func otherCandidatesHaveNoRegistration() {
        #expect(DerivedCandidateOrigin.sourceEntries(
            of: Candidate(storageText: "検討した", source: .systemDictionary),
            in: registered
        ).isEmpty)
        #expect(DerivedCandidateOrigin.sourceEntries(
            of: Candidate(
                storageText: "健闘した",
                source: .verbInflection,
                inflectionBase: InflectionBaseIdentity(
                    kind: .verb, reading: "kentousuru", surface: "健闘する", inflectionType: "suru"
                )
            ),
            in: registered
        ).isEmpty)
    }
}
