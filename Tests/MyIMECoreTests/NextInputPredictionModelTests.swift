import Foundation
import Testing
@testable import MyIMECore

@Suite
struct NextInputPredictionModelTests {
    @Test
    func learnsFollowingInput() {
        var model = NextInputPredictionModel()
        model.record("構造計画研究所")
        model.record("について")
        model.record("構造計画研究所")
        model.record("について")

        #expect(
            model.candidates(after: "構造計画研究所") == ["について"]
        )
    }

    @Test
    func returnsCandidatesForCurrentContext() {
        var model = NextInputPredictionModel()
        model.record("構造")
        model.record("計画")
        model.breakSequence()
        model.record("構造")

        #expect(model.candidatesAfterLastInput() == ["計画"])
    }

    @Test
    func prioritizesMostRecentFollower() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.record("A")
        model.record("B")
        model.record("A")
        model.record("C")

        #expect(model.candidates(after: "A") == ["C", "B"])
    }

    @Test
    func ordersEveryCandidateByMostRecentUse() {
        var model = NextInputPredictionModel()
        for follower in ["B", "B", "B", "D", "C"] {
            model.record("A")
            model.record(follower)
            model.breakSequence()
        }

        #expect(model.candidates(after: "A") == ["C", "D", "B"])
    }

    @Test
    func retainsMostRecentFollowerWhenPruning() {
        var model = NextInputPredictionModel()
        for index in 0..<NextInputPredictionModel.maximumFollowersPerContext {
            for _ in 0..<2 {
                model.record("A")
                model.record("候補\(index)")
                model.breakSequence()
            }
        }
        model.record("A")
        model.record("直前候補")

        #expect(model.candidates(after: "A", limit: 30).contains("直前候補"))
    }

    @Test
    func prunesOldContextsAndLowPriorityFollowers() {
        var model = NextInputPredictionModel()
        for index in 0...NextInputPredictionModel.maximumContextCount {
            model.record("文脈\(index)")
            model.record("候補\(index)")
            model.breakSequence()
        }
        for index in 0...NextInputPredictionModel.maximumFollowersPerContext {
            model.record("共通")
            model.record("候補\(index)")
            model.breakSequence()
        }

        #expect(model.contextCount == NextInputPredictionModel.maximumContextCount)
        #expect(
            model.candidates(after: "共通", limit: 30).count
                == NextInputPredictionModel.maximumFollowersPerContext
        )
        #expect(model.candidates(after: "文脈0").isEmpty)
        #expect(model.candidates(after: "共通").first == "候補16")
    }

    @Test
    func clearsLearnedData() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.removeAll()

        #expect(model.candidates(after: "A").isEmpty)
        #expect(model.contextCount == 0)
        #expect(model.lastInput == nil)
    }

    @Test
    func suppressesADeletedCandidateForEveryContext() {
        var model = NextInputPredictionModel()
        model.record("よろしく")
        model.record("お願いします")
        model.breakSequence()
        model.record("確認")
        model.record("お願いします")
        model.suppress("お願いします", after: "よろしく")

        #expect(model.candidates(after: "よろしく").isEmpty)
        #expect(model.candidates(after: "確認").isEmpty)
        #expect(model.isSuppressed("お願いします", after: "よろしく"))
        #expect(model.isSuppressed("お願いします", after: "別の文脈"))
    }

    @Test
    func persistsSuppressedCandidates() throws {
        var model = NextInputPredictionModel()
        model.suppress("円", after: "100")

        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: JSONEncoder().encode(model)
        )

        #expect(restored.isSuppressed("円", after: "100"))
    }

    @Test
    func migratesContextualSuppressionToGlobalSuppression() throws {
        let data = Data("""
        {
          "contexts": {},
          "sequence": 0,
          "lastInput": null,
          "suppressedCandidates": {
            "100": ["円"],
            "200": ["個", "円"]
          }
        }
        """.utf8)

        let restored = try JSONDecoder().decode(
            NextInputPredictionModel.self,
            from: data
        )

        #expect(restored.isSuppressed("円", after: "別の文脈"))
        #expect(restored.isSuppressed("個", after: "別の文脈"))
    }

    @Test
    func ignoresOversizedValue() {
        var model = NextInputPredictionModel()
        model.record(String(repeating: "a", count: 81))

        #expect(model.lastInput == nil)
        #expect(model.contextCount == 0)
    }

    @Test
    func breaksSequenceWithoutDeletingLearning() {
        var model = NextInputPredictionModel()
        model.record("A")
        model.record("B")
        model.breakSequence()
        model.record("C")

        #expect(model.candidates(after: "A") == ["B"])
        #expect(model.candidates(after: "B").isEmpty)
    }

    @Test
    func doesNotLearnFirstInputAfterLineBreakAsFollower() {
        var model = NextInputPredictionModel()
        model.record("改行前")
        model.breakSequence()
        model.record("次の行")

        #expect(model.candidates(after: "改行前").isEmpty)
        #expect(model.lastInput == "次の行")
    }
}
