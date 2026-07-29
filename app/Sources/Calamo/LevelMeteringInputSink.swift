import CalamoFeedback
import CalamoInput

/// Feeds the overlay's waveform from the same chunks the engine receives —
/// the level shown is the level heard.
final class LevelMeteringInputSink: DictationInputSink {
    private let wrapped: DictationInputSink
    private let onLevel: @Sendable (Float) -> Void

    init(wrapping wrapped: DictationInputSink, onLevel: @escaping @Sendable (Float) -> Void) {
        self.wrapped = wrapped
        self.onLevel = onLevel
    }

    func hotkeyPressed() { wrapped.hotkeyPressed() }

    func pushAudio(samples: [Float]) {
        onLevel(MicLevel.normalized(samples: samples))
        wrapped.pushAudio(samples: samples)
    }

    func hotkeyReleased() { wrapped.hotkeyReleased() }

    func captureFailed(_ failure: CaptureFailure) { wrapped.captureFailed(failure) }
}
