import Testing
@testable import MyIMECore

@Suite
struct EmojiVariationGroupingTests {
    @Test
    func groupsSkinToneSequencesUnderTheirExistingBase() {
        let grouping = EmojiVariationGrouping(codes: [
            "1f600",
            "1f44d",
            "1f44d-1f3fb",
            "1f44d-1f3ff"
        ])

        #expect(grouping.mainCodes == ["1f600", "1f44d"])
        #expect(grouping.memberCodes(forBaseCode: "1f44d") == [
            "1f44d",
            "1f44d-1f3fb",
            "1f44d-1f3ff"
        ])
    }

    @Test
    func groupsGenderAndSkinToneSequencesUnderNeutralBase() {
        let grouping = EmojiVariationGrouping(codes: [
            "1f64d",
            "1f64d-1f3fb",
            "1f64d-200d-2640",
            "1f64d-1f3fb-200d-2640",
            "1f64d-200d-2642"
        ])

        #expect(grouping.mainCodes == ["1f64d"])
        #expect(grouping.memberCodes(forBaseCode: "1f64d") == [
            "1f64d",
            "1f64d-1f3fb",
            "1f64d-200d-2640",
            "1f64d-1f3fb-200d-2640",
            "1f64d-200d-2642"
        ])
    }

    @Test
    func groupsGenderedPersonSequencesWhenNeutralSequenceExists() {
        let neutral = "1f9d1-200d-2695"
        let grouping = EmojiVariationGrouping(codes: [
            "1f468-200d-2695",
            "1f469-1f3ff-200d-2695",
            neutral
        ])

        #expect(grouping.mainCodes == [neutral])
        #expect(grouping.memberCodes(forBaseCode: neutral) == [
            neutral,
            "1f468-200d-2695",
            "1f469-1f3ff-200d-2695"
        ])
    }

    @Test
    func keepsCatalogSequenceWhenNoBaseExists() {
        let genderOnly = "1f9d1-200d-2695-200d-2640"
        let grouping = EmojiVariationGrouping(codes: [genderOnly, "1f600"])

        #expect(grouping.mainCodes == [genderOnly, "1f600"])
        #expect(grouping.memberCodes(forBaseCode: genderOnly) == [genderOnly])
    }

    @Test
    func groupsCompoundSequencesWithoutGeneratingNewOnes() {
        let base = "1f9d1-200d-1f91d-200d-1f9d1"
        let mixedTone = "1f9d1-1f3fb-200d-1f91d-200d-1f9d1-1f3ff"
        let grouping = EmojiVariationGrouping(codes: [base, mixedTone])

        #expect(grouping.mainCodes == [base])
        #expect(grouping.memberCodes(forBaseCode: base) == [base, mixedTone])
    }
}
