// ASR golden suite: the corpus takes through the real boosted FluidAudio
// adapter, against the manifest's verbatim references. On-demand only
// (CALAMO_GOLDEN=1), on the calibrated reference machine, never in CI.
import CalamoCore
import CalamoTranscription
import FluidAudio
import Foundation
import Testing

struct AsrGoldenSuite {
    struct TakeOutcome {
        let id: String
        let text: String
        let distance: Int
        let referenceCount: Int
        let failures: [String]
    }

    @Test(.enabled(if: GoldenGate.isRequested))
    func givenTheCorpusWhenTranscribedOnTheRealAdapterThenTheAsrGoldenHolds() throws {
        GoldenGate.modelLock.lock()
        defer { GoldenGate.modelLock.unlock() }

        // Given: the literal thresholds, the contract's takes and boost list,
        // the private verbatim references, the real adapter
        let vectors: AsrGoldenVectors = try GoldenFixtures.decode("asr-golden.json")
        let contract: TranscriptionContract = try GoldenFixtures.decode(vectors.contract)
        let manifest = try GoldenFixtures.manifest(for: contract)
        let adapter = try FluidAudioTranscription.load(
            paths: .defaultCache(), minSimilarity: contract.boost.minSimilarity)

        // When: every take transcribed with the full boost list
        let outcomes = try contract.takes.map { vector in
            try transcribed(vector, adapter, contract, manifest)
        }

        // Then: per-take hard assertions, literal aggregate WER budgets, and
        // byte-stability against the baseline
        var failures = outcomes.flatMap(\.failures)
        failures += aggregateBreaches(outcomes, budgets: vectors.aggregateWerBudget)
        failures += try GoldenBaseline.checkOrBootstrap(
            name: "asr-baseline.json",
            environment: environment(minSimilarity: contract.boost.minSimilarity),
            outputs: Dictionary(uniqueKeysWithValues: outcomes.map { ($0.id, $0.text) }))
        #expect(failures.isEmpty, "\n\(failures.joined(separator: "\n"))")
    }

    private func transcribed(
        _ vector: TranscriptionContract.Vector,
        _ adapter: FluidAudioTranscription,
        _ contract: TranscriptionContract,
        _ manifest: CorpusManifest
    ) throws -> TakeOutcome {
        let take = try transcribeTake(vector, adapter, contract, manifest)
        let failures = neverSpokenBreaches(
            contract.neverSpokenTerms,
            id: vector.id, output: take.text, verbatim: take.fixture.verbatim)
        let (distance, referenceCount) = TextMetrics.editDistance04(
            hypothesis: take.text, reference: take.fixture.verbatim)
        let wer = Double(distance) / Double(max(referenceCount, 1))
        print("[asr-golden] \(vector.id)  wer \(String(format: "%.3f", wer))")
        failures.forEach { print("[asr-golden]   HARD \($0)") }
        return TakeOutcome(
            id: vector.id, text: take.text,
            distance: distance, referenceCount: referenceCount, failures: failures)
    }

    /// Micro-averaged per language group; groups without a budget (the mixed
    /// takes) are reported, never gated.
    private func aggregateBreaches(_ outcomes: [TakeOutcome], budgets: [String: Double])
        -> [String]
    {
        var failures: [String] = []
        let groups = Dictionary(grouping: outcomes) { String($0.id.prefix(2)) }
        for (group, members) in groups.sorted(by: { $0.key < $1.key }) {
            let wer = Double(members.map(\.distance).reduce(0, +))
                / Double(max(members.map(\.referenceCount).reduce(0, +), 1))
            let formatted = String(format: "%.3f", wer)
            switch budgets[group] {
            case .none:
                print("[asr-golden] aggregate WER \(group) \(formatted)  (report only)")
            case .some(let budget):
                print("[asr-golden] aggregate WER \(group) \(formatted)  (budget \(budget))")
                if wer > budget {
                    failures.append("aggregate WER \(group) \(formatted) above the \(budget) budget")
                }
            }
        }
        return failures
    }

    private func environment(minSimilarity: Float) -> GoldenEnvironment {
        var pins = GoldenBaseline.transcriptionPins()
        pins["boostMinSimilarity"] = "\(minSimilarity)"
        return GoldenBaseline.currentEnvironment(pins: pins)
    }
}
