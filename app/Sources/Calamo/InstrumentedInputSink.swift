import CalamoInput
import Foundation

/// The push-to-talk demo's instrumented core, enabled by CALAMO_INPUT_DEMO=1.
final class InstrumentedInputSink: DictationInputSink {
    private let wrapped: DictationInputSink

    init(wrapping wrapped: DictationInputSink) {
        self.wrapped = wrapped
    }

    func hotkeyPressed() {
        log("hotkey_pressed")
        wrapped.hotkeyPressed()
    }

    func pushAudio(samples: [Float]) {
        log("push_audio — chunk of \(samples.count) samples")
        wrapped.pushAudio(samples: samples)
    }

    func hotkeyReleased() {
        log("hotkey_released")
        wrapped.hotkeyReleased()
    }

    func captureFailed(_ failure: CaptureFailure) {
        log("capture_failed — \(failure)")
        wrapped.captureFailed(failure)
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("[input→core] \(message)\n".utf8))
    }
}
