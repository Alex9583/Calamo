// Always-on guard: malformed golden vectors must fail loudly here, in CI —
// the gated suites would just never unroll them.
import Foundation
import Testing

struct GoldenVectorsGuardTests {
    @Test func givenTheCommittedAsrVectorsWhenDecodedThenThresholdsAndContractAreSound() throws {
        // When
        let vectors: AsrGoldenVectors = try GoldenFixtures.decode("asr-golden.json")
        let contract: TranscriptionContract = try GoldenFixtures.decode(vectors.contract)

        // Then: a budget per gated language group, takes to unroll them on
        #expect(vectors.aggregateWerBudget["fr"] != nil)
        #expect(vectors.aggregateWerBudget["en"] != nil)
        #expect(vectors.aggregateWerBudget.values.allSatisfy { $0 > 0 && $0 < 1 })
        #expect(!contract.takes.isEmpty)
        #expect(!contract.boost.entries.isEmpty)
    }

    @Test func givenTheCommittedE2eVectorsWhenDecodedThenThresholdsAndContractAreSound() throws {
        // When
        let vectors: E2eGoldenVectors = try GoldenFixtures.decode("e2e-golden.json")
        let contract: TranscriptionContract = try GoldenFixtures.decode(vectors.contract)

        // Then
        #expect(vectors.minSimilarityVsClean > 0 && vectors.minSimilarityVsClean <= 1)
        #expect(vectors.maxTakesBelowSimilarity < contract.takes.count)
        #expect(!contract.neverSpokenTerms.isEmpty)
    }

    @Test func givenThePrivateManifestWhenPresentThenTheContractTakesCoverIt() throws {
        // Given: only the reference machine has the corpus
        let contract: TranscriptionContract = try GoldenFixtures.decode(
            "transcription-contract.json")
        let manifest: CorpusManifest
        do {
            manifest = try GoldenFixtures.manifest(for: contract)
        } catch CorpusManifest.ManifestError.absent {
            print("SKIP: private corpus manifest absent")
            return
        }

        // Then: same takes on both sides, references never empty
        #expect(manifest.fixtures.count == contract.takes.count)
        for vector in contract.takes {
            let fixture = try manifest.fixture(vector.id)
            #expect(!fixture.verbatim.isEmpty)
            #expect(!fixture.clean.isEmpty)
        }
    }
}
