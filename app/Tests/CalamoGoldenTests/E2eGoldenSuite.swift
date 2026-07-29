// E2E golden suite: the corpus takes through the real DictationEngine chain
// — FluidAudio transcription, Qwen3.5-2B cleanup, SpellingEnforcement — with
// the insertion port doubled. On-demand only (CALAMO_GOLDEN=1), on the
// calibrated reference machine, never in CI.
import CalamoCore
import CalamoTranscription
import FluidAudio
import Foundation
import NaturalLanguage
import Testing

struct E2eGoldenSuite {
    struct TakeOutcome {
        let id: String
        let language: String
        let text: String
        let similarity: Double
        let failures: [String]
    }

    /// The spelling the hot-edit demo adds while dictating mx-01.
    private let hotEditSpelling = "Design System"

    @Test(.enabled(if: GoldenGate.isRequested))
    func givenAHotEditedDictionaryWhenTheCorpusIsDictatedThroughTheRealChainThenTheE2eGoldenHolds()
        throws
    {
        GoldenGate.modelLock.lock()
        defer { GoldenGate.modelLock.unlock() }

        // Given: the literal thresholds, the private references, the real
        // chain whose dictionary starts without the hot-edit term
        let vectors: E2eGoldenVectors = try GoldenFixtures.decode("e2e-golden.json")
        let contract: TranscriptionContract = try GoldenFixtures.decode(vectors.contract)
        let manifest = try GoldenFixtures.manifest(for: contract)
        let stack = try E2eStack.load(
            dictionary: contract.dictionaryToml(excluding: [hotEditSpelling]))

        // When: the term is dictated, hot-added, redictated — then every take
        // dictated end to end, in corpus order
        var failures = try hotEditBreaches(stack, contract)
        let outcomes = try contract.takes.map { vector in
            dictated(vector, stack, contract, try manifest.fixture(vector.id))
        }

        // Then: per-take hard assertions, the literal similarity budget, and
        // byte-stability against the baseline
        failures += outcomes.flatMap(\.failures)
        failures += similarityBreaches(outcomes, vectors: vectors)
        failures += try GoldenBaseline.checkOrBootstrap(
            name: "e2e-baseline.json",
            environment: environment(),
            outputs: Dictionary(uniqueKeysWithValues: outcomes.map { ($0.id, $0.text) }))
        #expect(failures.isEmpty, "\n\(failures.joined(separator: "\n"))")
    }

    /// Dictated without its entry, the spelling lands however ASR heard it;
    /// added to the TOML and hot-reloaded — same engine, no restart — the
    /// same take lands with the exact spelling.
    private func hotEditBreaches(_ stack: E2eStack, _ contract: TranscriptionContract)
        throws -> [String]
    {
        let take = try #require(contract.takes.first { $0.id == "mx-01" })
        let audio = try samples(for: take, in: contract)
        var breaches = [String]()
        let before = try stack.dictate(audio)
        if TextMetrics.termExact(hotEditSpelling, in: before) {
            breaches.append(
                "hot-edit: « \(hotEditSpelling) » already exact without its entry in: \(before)")
        }
        try stack.editDictionary(contract.dictionaryToml())
        let after = try stack.dictate(audio)
        if !TextMetrics.termExact(hotEditSpelling, in: after) {
            breaches.append(
                "hot-edit: « \(hotEditSpelling) » not exact after the edit in: \(after)")
        }
        print("[e2e-golden] hot-edit mx-01: « \(before) » → « \(after) »")
        return breaches
    }

    private func dictated(
        _ vector: TranscriptionContract.Vector,
        _ stack: E2eStack,
        _ contract: TranscriptionContract,
        _ fixture: CorpusFixture
    ) -> TakeOutcome {
        let text: String
        do {
            text = try stack.dictate(samples(for: vector, in: contract))
        } catch {
            return failedOutcome(vector, error)
        }
        let language = finalTextLanguage(text)
        let outcome = TakeOutcome(
            id: vector.id,
            language: language,
            text: text,
            similarity: TextMetrics.levenshteinSimilarity04(text, fixture.clean),
            failures: hardBreaches(vector, fixture, contract, language: language, text: text))
        report(outcome)
        return outcome
    }

    private func samples(
        for vector: TranscriptionContract.Vector, in contract: TranscriptionContract
    ) throws -> [Float] {
        try AudioConverter()
            .resampleAudioFile(path: GoldenFixtures.audioURL(vector.id, in: contract).path)
    }

    private func failedOutcome(_ vector: TranscriptionContract.Vector, _ error: any Error)
        -> TakeOutcome
    {
        let failure = "\(vector.id): \(error)"
        print("[e2e-golden] \(vector.id)  FAILED \(failure)")
        return TakeOutcome(id: vector.id, language: "", text: "", similarity: 0, failures: [failure])
    }

    private func hardBreaches(
        _ vector: TranscriptionContract.Vector,
        _ fixture: CorpusFixture,
        _ contract: TranscriptionContract,
        language: String,
        text: String
    ) -> [String] {
        var breaches = languageBreach(
            id: vector.id, detected: language, expected: vector.language, in: text)
        breaches += neverSpokenBreaches(
            contract.neverSpokenTerms, id: vector.id, output: text, verbatim: fixture.verbatim)
        breaches += spellingBreaches(
            vector.id, contract.boost.entries, clean: fixture.clean, in: text)
        return breaches
    }

    private func spellingBreaches(
        _ id: String, _ entries: [TranscriptionContract.Entry], clean: String, in text: String
    ) -> [String] {
        entries
            .filter {
                TextMetrics.termExact($0.text, in: clean)
                    && TextMetrics.termPresent($0.text, in: text)
                    && !TextMetrics.termExact($0.text, in: text)
            }
            .map { "\(id): spelling of « \($0.text) » not exact in: \(text)" }
    }

    private func report(_ outcome: TakeOutcome) {
        print(
            "[e2e-golden] \(outcome.id)  lang \(outcome.language)  "
                + "sim \(String(format: "%.3f", outcome.similarity))")
        outcome.failures.forEach { print("[e2e-golden]   HARD \($0)") }
    }

    private func similarityBreaches(_ outcomes: [TakeOutcome], vectors: E2eGoldenVectors)
        -> [String]
    {
        let below = outcomes.filter { $0.similarity < vectors.minSimilarityVsClean }.map(\.id)
        print(
            "[e2e-golden] takes below \(vectors.minSimilarityVsClean): \(below.count)/"
                + "\(outcomes.count) (budget \(vectors.maxTakesBelowSimilarity))")
        guard below.count > vectors.maxTakesBelowSimilarity else { return [] }
        return [
            "\(below.count) takes below similarity \(vectors.minSimilarityVsClean) "
                + "(budget \(vectors.maxTakesBelowSimilarity)): \(below.joined(separator: ", "))"
        ]
    }

    /// FluidAudio's batch API exposes no language field; like the prototype,
    /// the assertion reads the final text through constrained fr/en LID.
    private func finalTextLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.french, .english]
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
        return (hypotheses[.french] ?? 0) > (hypotheses[.english] ?? 0) ? "fr" : "en"
    }

    private func environment() -> GoldenEnvironment {
        var pins = GoldenBaseline.transcriptionPins()
        pins["llamaCpp2"] = GoldenBaseline.lockedCrateVersion("llama-cpp-2")
        return GoldenBaseline.currentEnvironment(pins: pins)
    }
}
