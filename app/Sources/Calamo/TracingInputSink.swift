import CalamoInput

/// Times each push_audio FFI call and stamps the press and release before
/// they cross, so the traced latencies cover the press-to-pill and
/// release-to-insertion paths whole.
final class TracingInputSink: DictationInputSink {
    private let wrapped: DictationInputSink
    private let trace: PipelineTrace

    init(wrapping wrapped: DictationInputSink, trace: PipelineTrace) {
        self.wrapped = wrapped
        self.trace = trace
    }

    func hotkeyPressed() {
        trace.recordPress()
        wrapped.hotkeyPressed()
    }

    func pushAudio(samples: [Float]) {
        trace.measurePush { wrapped.pushAudio(samples: samples) }
    }

    func hotkeyReleased() {
        trace.recordRelease()
        wrapped.hotkeyReleased()
    }

    func captureFailed(_ failure: CaptureFailure) {
        wrapped.captureFailed(failure)
    }
}
