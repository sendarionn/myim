import Testing
@testable import MyIMECore

@Suite
struct JapaneseAdjectiveDictionaryTests {
    @Test
    func distinguishesNaAndIAdjectivesByReadingAndSurface() {
        let dictionary = JapaneseAdjectiveDictionary(text: """
            benri\t便利\tna-adjective-stem\t1200
            sugoi\tすごい\ti-adjective\t1300
            invalid\tentry\tunknown\t0
            """)

        #expect(dictionary.contains(
            reading: "benri",
            surface: "便利",
            class: .naAdjectiveStem
        ))
        #expect(dictionary.contains(
            reading: "sugoi",
            surface: "すごい",
            class: .iAdjective
        ))
        #expect(!dictionary.contains(
            reading: "benri",
            surface: "便利",
            class: .iAdjective
        ))
        #expect(!dictionary.contains(
            reading: "gakusei",
            surface: "学生",
            class: .naAdjectiveStem
        ))
    }
}
