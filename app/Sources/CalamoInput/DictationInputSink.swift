public enum CaptureFailure: Error, Equatable, Sendable {
    case micUnavailable
    case permissionDenied
}

/// Core-facing side of the input path; the app plugs the DictationEngine in.
/// Sendable: called from the push-to-talk and audio-capture queues.
public protocol DictationInputSink: AnyObject, Sendable {
    func hotkeyPressed()
    func pushAudio(samples: [Float])
    func hotkeyReleased()
    func captureFailed(_ failure: CaptureFailure)
}
