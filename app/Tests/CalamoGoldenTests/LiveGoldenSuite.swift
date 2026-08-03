// Live golden suite: real-mic takes in live conditions with the template
// dictionary boosted — the small-dictionary regime (docs/golden-suites.md).
// On-demand only (CALAMO_GOLDEN=1), on the calibrated reference machine,
// never in CI.
import CalamoCore
import CalamoTranscription
import FluidAudio
import Foundation
import Testing

struct LiveGoldenSuite {
    struct TakeOutcome {
        let id: String
        let language: String
        let text: String
        let failures: [String]
    }

    @Test(.enabled(if: GoldenGate.isRequested))
    func givenTheLiveCorpusWhenTranscribedWithTheTemplateDictionaryThenBoostInjectsNothing()
        throws
    {
        GoldenGate.modelLock.lock()
        defer { GoldenGate.modelLock.unlock() }

        // Given: the template dictionary as boost list, the private live takes
        let contract: TranscriptionContract = try GoldenFixtures.decode("live-contract.json")
        let manifest = try GoldenFixtures.manifest(for: contract)
        let adapter = try FluidAudioTranscription.load(
            paths: .defaultCache(), minSimilarity: contract.boost.minSimilarity)

        // When: every take transcribed with the template boosted
        let outcomes = try contract.takes.map { vector in
            try transcribed(vector, adapter, contract, manifest)
        }

        // Then: hard per-take assertions and byte-stability against the baseline
        var failures = outcomes.flatMap(\.failures)
        failures += try GoldenBaseline.checkOrBootstrap(
            name: "live-baseline.json",
            environment: environment(minSimilarity: contract.boost.minSimilarity),
            outputs: Dictionary(
                uniqueKeysWithValues: outcomes.map { ($0.id, "[\($0.language)] \($0.text)") }))
        #expect(failures.isEmpty, "\n\(failures.joined(separator: "\n"))")
    }

    private func transcribed(
        _ vector: TranscriptionContract.Vector,
        _ adapter: FluidAudioTranscription,
        _ contract: TranscriptionContract,
        _ manifest: CorpusManifest
    ) throws -> TakeOutcome {
        let take = try transcribeTake(vector, adapter, contract, manifest)
        var failures = take.languageFailures
        failures += injectedTermBreaches(
            contract.boostList,
            id: vector.id, output: take.text, verbatim: take.fixture.verbatim)
        failures += missingTermBreaches(
            vector.expectedTerms ?? [], id: vector.id, output: take.text)
        print("[live-golden] \(vector.id)  lang \(take.language)  \(take.text)")
        failures.forEach { print("[live-golden]   HARD \($0)") }
        return TakeOutcome(
            id: vector.id, language: take.language, text: take.text, failures: failures)
    }

    private func environment(minSimilarity: Float) -> GoldenEnvironment {
        var pins = GoldenBaseline.transcriptionPins()
        pins["boostMinSimilarity"] = "\(minSimilarity)"
        pins["spotterRescue"] =
            ConservativeBoost.rescorerConfig.spotterRescueEnabled ? "enabled" : "disabled"
        return GoldenBaseline.currentEnvironment(pins: pins)
    }
}
