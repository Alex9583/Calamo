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

    @Test func givenTheCommittedLiveContractWhenDecodedThenItMirrorsTheDictionaryTemplate() throws {
        // Given: the shipped template literal
        let source = try String(
            contentsOf: GoldenFixtures.repoRoot
                .appendingPathComponent("core/calamo-adapters/src/dictionary.rs"),
            encoding: .utf8)
        let template = try #require(rawStringLiteral(in: source))

        // When
        let contract: TranscriptionContract = try GoldenFixtures.decode("live-contract.json")

        // Then: takes to unroll, every rendered entry line verbatim in the
        // template, and no extra entry there
        #expect(!contract.takes.isEmpty)
        #expect(contract.takes.contains { !($0.expectedTerms ?? []).isEmpty })
        for line in contract.dictionaryToml().split(separator: "\n").dropFirst().dropLast() {
            #expect(template.contains(line), "entry drifted from the template: \(line)")
        }
        #expect(template.components(separatedBy: "{ text =").count - 1 == contract.boost.entries.count)
    }

    private func rawStringLiteral(in source: String) -> Substring? {
        guard let open = source.range(of: "r#\""),
            let close = source.range(of: "\"#", range: open.upperBound..<source.endIndex)
        else { return nil }
        return source[open.upperBound..<close.lowerBound]
    }

    @Test func givenThePrivateLiveManifestWhenPresentThenTheContractTakesCoverIt() throws {
        // Given: only the reference machine has the live corpus
        let contract: TranscriptionContract = try GoldenFixtures.decode("live-contract.json")
        let manifest: CorpusManifest
        do {
            manifest = try GoldenFixtures.manifest(for: contract)
        } catch CorpusManifest.ManifestError.absent {
            print("SKIP: private live corpus manifest absent")
            return
        }

        // Then
        #expect(manifest.fixtures.count == contract.takes.count)
        for vector in contract.takes {
            #expect(try !manifest.fixture(vector.id).verbatim.isEmpty)
        }
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
