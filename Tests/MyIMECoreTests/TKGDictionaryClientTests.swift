import Foundation
import Testing
@testable import MyIMECore

@Suite
struct TKGDictionaryClientTests {
    @Test
    func convertsIndexInTierOrderAndMergesReadings() throws {
        let source = """
        {
          "metadata": {
            "generated": "2026-07-28T09:38:39Z",
            "total_entries": 3
          },
          "entries": [
            {
              "id": "00003_miru",
              "headword": "観る",
              "vocabulary_tier": "general"
            },
            {
              "id": "00001_miru",
              "headword": "見る",
              "vocabulary_tier": "basic"
            },
            {
              "id": "00002_iku",
              "headword": "行く",
              "vocabulary_tier": "core"
            }
          ]
        }
        """

        let result = try TKGDictionaryClient().convert(Data(source.utf8))

        #expect(result.generatedAt == "2026-07-28T09:38:39Z")
        #expect(result.sourceEntryCount == 3)
        #expect(
            result.entries == [
                DictionaryEntry(reading: "miru", candidates: ["見る", "観る"]),
                DictionaryEntry(reading: "iku", candidates: ["行く"])
            ]
        )
    }

    @Test
    func splitsAlternativeHeadwordSpellings() throws {
        let source = """
        {
          "metadata": {"generated": "2026-08-02", "total_entries": 1},
          "entries": [{
            "id": "basic_hayai",
            "headword": "速い／早い",
            "vocabulary_tier": "basic"
          }]
        }
        """
        let data = Data(source.utf8)
        let snapshot = try TKGDictionaryClient().convert(data)
        #expect(snapshot.entries == [
            DictionaryEntry(reading: "hayai", candidates: ["速い", "早い"])
        ])
    }

    @Test
    func removesPlaceholderWaveDashFromHeadword() throws {
        let source = """
        {
          "metadata": {"generated": "2026-08-02", "total_entries": 1},
          "entries": [{
            "id": "basic_nado",
            "headword": "〜など",
            "vocabulary_tier": "basic"
          }]
        }
        """
        let snapshot = try TKGDictionaryClient().convert(Data(source.utf8))
        #expect(snapshot.entries == [
            DictionaryEntry(reading: "nado", candidates: ["など"])
        ])
    }
}
