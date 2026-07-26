public enum CaptureFailure: Error, Equatable {
    case micUnavailable
    case permissionDenied
}

/// Core-facing side of the input path; the app plugs the DictationEngine in.
public protocol DictationInputSink: AnyObject {
    func hotkeyPressed()
    func pushAudio(samples: [Float])
    func hotkeyReleased()
    func captureFailed(_ failure: CaptureFailure)
}
