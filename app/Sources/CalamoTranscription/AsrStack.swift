// Models come strictly from local paths — ASR presence is checked up front so
// ModelHub never falls back to a network download.
import CalamoCore
import FluidAudio
import Foundation

final class AsrStack: @unchecked Sendable {
    private let asrManager: AsrManager
    private let spotter: CtcKeywordSpotter
    private let tokenizer: CtcTokenizer
    private let ctcDirectory: URL
    private let minSimilarity: Float

    private let boostLock = NSLock()
    private var cachedBoost: Boost?

    private init(
        asrManager: AsrManager,
        spotter: CtcKeywordSpotter,
        tokenizer: CtcTokenizer,
        ctcDirectory: URL,
        minSimilarity: Float
    ) {
        self.asrManager = asrManager
        self.spotter = spotter
        self.tokenizer = tokenizer
        self.ctcDirectory = ctcDirectory
        self.minSimilarity = minSimilarity
    }

    static func load(paths: TranscriptionModelPaths, minSimilarity: Float) async throws -> AsrStack {
        guard AsrModels.modelsExist(at: paths.asrModels) else {
            throw TranscriptionSetupError.modelsMissing(paths.asrModels)
        }
        let models = try await AsrModels.load(from: paths.asrModels, version: .v3)
        let asrManager = AsrManager(config: .default)
        try await asrManager.loadModels(models)

        let ctcModels = try await CtcModels.loadDirect(from: paths.ctcModels)
        let spotter = CtcKeywordSpotter(models: ctcModels, blankId: ctcModels.vocabulary.count)
        let tokenizer = try await CtcTokenizer.load(from: paths.ctcModels)
        return AsrStack(
            asrManager: asrManager,
            spotter: spotter,
            tokenizer: tokenizer,
            ctcDirectory: paths.ctcModels,
            minSimilarity: minSimilarity
        )
    }

    func transcribe(_ samples: [Float], boostList: [BoostEntry]) async throws -> String {
        var state = TdtDecoderState.make(decoderLayers: await asrManager.decoderLayerCount)
        guard let boost = try await boost(for: boostList) else {
            return try await asrManager.transcribe(samples, decoderState: &state).text
        }

        async let spotting = spotter.spotKeywordsWithLogProbs(
            audioSamples: samples, customVocabulary: boost.vocabulary, minScore: nil)
        let tdt = try await asrManager.transcribe(samples, decoderState: &state)
        let spotted = try await spotting

        guard let timings = tdt.tokenTimings, !timings.isEmpty, !spotted.logProbs.isEmpty else {
            return tdt.text
        }
        let rescored = boost.rescorer.ctcTokenRescore(
            transcript: tdt.text,
            tokenTimings: timings,
            logProbs: spotted.logProbs,
            frameDuration: spotted.frameDuration,
            cbw: boost.cbw,
            marginSeconds: ContextBiasingConstants.defaultMarginSeconds,
            // Explicit on purpose: the parameter's default is the auto scale
            // ConservativeBoost exists to avoid.
            minSimilarity: minSimilarity
        )
        return rescored.wasModified ? rescored.text : tdt.text
    }
}

private struct Boost {
    let entries: [BoostEntry]
    let vocabulary: CustomVocabularyContext
    let rescorer: VocabularyRescorer
    let cbw: Float
}

extension AsrStack {
    // The spotter and rescorer derive from the Dictionary's boost list, which
    // only changes on dictionary reload — cache them across dictations.
    private func boost(for entries: [BoostEntry]) async throws -> Boost? {
        guard !entries.isEmpty else { return nil }
        if let cached = withBoostLock({ cachedBoost }), cached.entries == entries { return cached }

        let terms = entries.compactMap { entry -> CustomVocabularyTerm? in
            let ctcTokenIds = tokenizer.encode(entry.canonicalText)
            guard !ctcTokenIds.isEmpty else { return nil }
            return CustomVocabularyTerm(
                text: entry.canonicalText,
                aliases: entry.aliases.isEmpty ? nil : entry.aliases,
                ctcTokenIds: ctcTokenIds,
                minSimilarity: ConservativeBoost.perTermMinSimilarity(forCanonical: entry.canonicalText)
            )
        }
        let vocabulary = CustomVocabularyContext(terms: terms, minSimilarity: minSimilarity)
        let rescorer = try await VocabularyRescorer.create(
            spotter: spotter, vocabulary: vocabulary, ctcModelDirectory: ctcDirectory)
        let boost = Boost(
            entries: entries,
            vocabulary: vocabulary,
            rescorer: rescorer,
            cbw: ContextBiasingConstants.rescorerConfig(forVocabSize: terms.count).cbw
        )
        withBoostLock { cachedBoost = boost }
        return boost
    }

    private func withBoostLock<T>(_ body: () -> T) -> T {
        boostLock.lock()
        defer { boostLock.unlock() }
        return body()
    }
}
