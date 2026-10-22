import Testing
@testable import MyIMECore

@Suite
struct RomajiKeyboardGeometryTests {
    @Test
    func distinguishesUSAndJISShiftedLongVowelKeys() {
        #expect(RomajiKeyboardGeometry.distance(
            from: "=",
            to: "-",
            layout: .jis
        ) == 0)
        #expect(RomajiKeyboardGeometry.distance(
            from: "=",
            to: "-",
            layout: .us
        ) == 1)
        #expect(RomajiKeyboardGeometry.distance(
            from: "_",
            to: "-",
            layout: .us
        ) == 0)
    }

    @Test
    func treatsZeroAsAdjacentToTheLongVowelKey() {
        for layout in RomajiKeyboardLayout.allCases {
            #expect(RomajiKeyboardGeometry.distance(
                from: "0",
                to: "-",
                layout: layout
            ) == 1)
        }
    }

    @Test
    func preservesTheExistingLetterKeyGeometry() throws {
        let adjacent = try #require(RomajiKeyboardGeometry.typoDistance(
            from: "r",
            to: "t"
        ))
        let distant = try #require(RomajiKeyboardGeometry.typoDistance(
            from: "r",
            to: "p"
        ))

        #expect(adjacent < distant)
    }
}

/// Typos are judged on the US layout only
@Suite
struct RomajiKeyboardUSTypoDistanceTests {
    @Test(arguments: [
        ("=", "-", 1.0), ("+", "-", 1.0), ("_", "-", 0.0), ("0", "-", 1.0),
        ("=", "+", 0.0), ("e", "r", 1.0), ("j", "k", 1.0)
    ])
    func measuresKeysOnTheUSLayout(
        source: Character,
        target: Character,
        distance: Double
    ) {
        #expect(RomajiKeyboardGeometry.typoDistance(
            from: source,
            to: target
        ) == distance)
    }

    /// `@` sits beside `p` and `:` beside `l` only on JIS
    @Test
    func doesNotUseJISNeighbors() throws {
        let jis = try #require(RomajiKeyboardGeometry.distance(
            from: "@",
            to: "p",
            layout: .jis
        ))
        let us = try #require(RomajiKeyboardGeometry.typoDistance(
            from: "@",
            to: "p"
        ))

        #expect(jis <= 1)
        #expect(us > 5)
        #expect(RomajiKeyboardTypoGenerator.corrections(for: "@ato")
            .allSatisfy { !$0.hasPrefix("p") })
    }

    @Test
    func farKeysCostMoreThanNeighbors() {
        #expect(RomajiTypoScorer.cost(from: "a=to", to: "a-to")
            < RomajiTypoScorer.cost(from: "a/to", to: "a-to"))
        #expect(RomajiTypoScorer.cost(from: "a_to", to: "a-to")
            <= RomajiTypoScorer.cost(from: "a=to", to: "a-to"))
    }

    @Test
    func longVowelKeyNeighborsAreTheSymbolsOnAndBesideIt() {
        #expect(RomajiKeyboardGeometry.longVowelKeyNeighbors
            == ["_", "=", "+", ")"])
    }
}
