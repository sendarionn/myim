import Testing
@testable import MyIMECore

@Suite
struct JapaneseAdjectiveInflectionCandidateGeneratorTests {
    private let generator = JapaneseAdjectiveInflectionCandidateGenerator(
        dictionary: JapaneseAdjectiveDictionary(text: """
            osoi\t遅い\ti-adjective\t1000
            hayai\t早い\ti-adjective\t900
            hayai\t速い\ti-adjective\t1000
            yoi\t良い\ti-adjective\t800
            ii\tいい\ti-adjective\t700
            kirei\t綺麗\tna-adjective-stem\t600
            gakusei\t学生\tna-adjective-stem\t500
            """)
    )

    @Test(arguments: [
        ("osokatta", ["遅かった"]),
        ("hayakatta", ["早かった", "速かった"]),
        ("osokunakatta", ["遅くなかった"]),
        ("yokatta", ["良かった"]),
        ("yokunakatta", ["良くなかった"])
    ])
    func generatesIAdjectivePastForms(
        input: String,
        expected: [String]
    ) {
        #expect(generator.candidates(for: input) == expected)
    }

    @Test(arguments: [
        "ordinary", "gakuseikatta", "kireikatta", "iikatta", "katta"
    ])
    func rejectsInputsWithoutAMatchingIAdjective(_ input: String) {
        #expect(generator.candidates(for: input).isEmpty)
    }

    @Test
    func limitsGeneratedCandidates() {
        #expect(generator.candidates(for: "hayakatta", limit: 1) == [
            "早かった"
        ])
    }
}
