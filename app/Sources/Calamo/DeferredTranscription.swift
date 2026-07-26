import CalamoCore
import CalamoTranscription
import Foundation

/// The TranscriptionPort as the app lives it: the adapter arrives once the
/// models load; until then — unreachable behind the engine's Ready gate —
/// every transcription fails.
final class DeferredTranscription: TranscriptionPort, @unchecked Sendable {
    private let lock = NSLock()
    private var adapter: FluidAudioTranscription?

    func install(_ adapter: FluidAudioTranscription) {
        lock.withLock { self.adapter = adapter }
    }

    func transcribe(samples: [Float], boostList: [BoostEntry]) throws -> RawTranscript {
        guard let adapter = lock.withLock({ adapter }) else {
            throw TranscriptionError.Failed(message: "transcription models not loaded")
        }
        return try adapter.transcribe(samples: samples, boostList: boostList)
    }
}
