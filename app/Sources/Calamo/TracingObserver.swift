import CalamoCore

/// Mirrors TracingInputSink on the outbound side: every engine event reaches
/// the trace before the UI model.
final class TracingObserver: DictationObserver, Sendable {
    private let wrapped: DictationObserver
    private let trace: PipelineTrace

    init(wrapping wrapped: DictationObserver, trace: PipelineTrace) {
        self.wrapped = wrapped
        self.trace = trace
    }

    func dictationStateChanged(dictation: UInt64, state: DictationState) {
        trace.dictationStateChanged(dictation: dictation, state: state)
        wrapped.dictationStateChanged(dictation: dictation, state: state)
    }

    func dictationRefused(cause: RefusalCause) {
        trace.dictationRefused(cause: cause)
        wrapped.dictationRefused(cause: cause)
    }

    func engineStateChanged(state: EngineState) {
        trace.engineStateChanged(state: state)
        wrapped.engineStateChanged(state: state)
    }
}
