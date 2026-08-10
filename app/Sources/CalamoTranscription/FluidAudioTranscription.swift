// The port stays synchronous: FluidAudio's async API is bridged internally,
// so `transcribe` must only ever be called from a plain thread — the engine's
// pipeline thread — never from the Swift cooperative pool.
import CalamoCore
import FluidAudio
import Foundation

public struct TranscriptionModelPaths: Sendable {
    public let asrModels: URL
    public let ctcModels: URL

    public init(asrModels: URL, ctcModels: URL) {
        self.asrModels = asrModels
        self.ctcModels = ctcModels
    }

    public static func defaultCache() -> TranscriptionModelPaths {
        TranscriptionModelPaths(
            asrModels: AsrModels.defaultCacheDirectory(for: .v3),
            ctcModels: CtcModels.defaultCacheDirectory(for: .ctc110m)
        )
    }
}

public enum TranscriptionSetupError: Error, Equatable {
    case modelsMissing(URL)
}

public final class FluidAudioTranscription: TranscriptionPort, @unchecked Sendable {
    private let stack: AsrStack

    private init(stack: AsrStack) {
        self.stack = stack
    }

    public static func load(
        paths: TranscriptionModelPaths,
        minSimilarity: Float = ConservativeBoost.globalMinSimilarity
    ) throws -> FluidAudioTranscription {
        let stack = try SyncBridge.run {
            try await AsrStack.load(paths: paths, minSimilarity: minSimilarity)
        }
        return FluidAudioTranscription(stack: stack)
    }

    public func transcribe(samples: [Float], boostList: [BoostEntry]) throws -> RawTranscript {
        // An empty Utterance must surface as an empty transcript so the engine
        // fails the dictation as EmptyDictation, not TranscriptionFailed.
        guard !samples.isEmpty else {
            return RawTranscript(text: "")
        }
        do {
            let stack = stack
            let text = try SyncBridge.run {
                try await stack.transcribe(samples, boostList: boostList)
            }
            return RawTranscript(text: text)
        } catch {
            throw TranscriptionError.Failed(message: String(describing: error))
        }
    }
}
