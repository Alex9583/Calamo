import CalamoCore
import CalamoInput

/// Bridges the input path onto the DictationEngine facade across the FFI.
final class EngineInputSink: DictationInputSink {
    private let engine: DictationEngine

    init(engine: DictationEngine) {
        self.engine = engine
    }

    func hotkeyPressed() { engine.hotkeyPressed() }

    func pushAudio(samples: [Float]) { engine.pushAudio(samples: samples) }

    func hotkeyReleased() { engine.hotkeyReleased() }

    func captureFailed(_ failure: CaptureFailure) {
        switch failure {
        case .micUnavailable: engine.captureFailed(incident: .micUnavailable)
        case .permissionDenied: engine.captureFailed(incident: .permissionRevoked)
        }
    }
}
