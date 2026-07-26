import CalamoInput

/// Times each push_audio FFI call and stamps the release before it crosses,
/// so the traced latency covers the whole release-to-insertion path.
final class TracingInputSink: DictationInputSink {
    private let wrapped: DictationInputSink
    private let trace: PipelineTrace

    init(wrapping wrapped: DictationInputSink, trace: PipelineTrace) {
        self.wrapped = wrapped
        self.trace = trace
    }

    func hotkeyPressed() { wrapped.hotkeyPressed() }

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
