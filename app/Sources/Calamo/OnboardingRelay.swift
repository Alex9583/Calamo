import CalamoCore

/// Fans the engine's ambient state and dictation completions out to the
/// wizard while the wrapped observer chain stays intact.
final class OnboardingRelay: DictationObserver {
    private let wrapped: DictationObserver
    private let onEngineState: @Sendable (EngineState) -> Void
    private let onDictationCompleted: @Sendable () -> Void

    init(
        wrapping wrapped: DictationObserver,
        onEngineState: @escaping @Sendable (EngineState) -> Void,
        onDictationCompleted: @escaping @Sendable () -> Void
    ) {
        self.wrapped = wrapped
        self.onEngineState = onEngineState
        self.onDictationCompleted = onDictationCompleted
    }

    func dictationStateChanged(dictation: UInt64, state: DictationState) {
        if case .completed = state { onDictationCompleted() }
        wrapped.dictationStateChanged(dictation: dictation, state: state)
    }

    func dictationRefused(cause: RefusalCause) {
        wrapped.dictationRefused(cause: cause)
    }

    func engineStateChanged(state: EngineState) {
        onEngineState(state)
        wrapped.engineStateChanged(state: state)
    }
}
