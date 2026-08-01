// Maps engine events to overlay steps and sound cues; the capture sounds
// track entering/leaving Capturing, whatever path the dictation takes.
import CalamoCore
import Foundation

public struct FeedbackMachine {
    private static let degradedNotice: TimeInterval = 1.0
    private static let briefNotice: TimeInterval = 1.5

    private var capturing = false
    /// Display of the dictation still in flight — what a refusal notice
    /// must give the pill back to.
    private var inFlight: OverlayDisplay?

    public init() {}

    public mutating func handle(_ state: DictationState) -> FeedbackReaction {
        let started = !capturing && state == .capturing
        let ended = capturing && state != .capturing
        capturing = state == .capturing
        let step = Self.step(for: state)
        inFlight =
            switch step.display {
            case .waveform, .waiting: step.display
            default: nil
            }
        return FeedbackReaction(
            step: step,
            sound: started ? .captureStart : ended ? .captureEnd : nil,
            notice: Self.notice(for: state)
        )
    }

    public func handle(refusal cause: RefusalCause) -> FeedbackReaction {
        let step = OverlayStep(
            display: .notice(Self.text(for: cause)), dissolveAfter: Self.briefNotice,
            revertsTo: inFlight
        )
        return FeedbackReaction(step: step, sound: nil)
    }

    private static func step(for state: DictationState) -> OverlayStep {
        switch state {
        case .capturing:
            OverlayStep(display: .waveform)
        case .transcribing, .cleaning, .inserting:
            OverlayStep(display: .waiting)
        case .completed(degraded: false):
            OverlayStep(display: .hidden)
        case .completed(degraded: true):
            OverlayStep(display: .notice("Inserted without cleanup"), dissolveAfter: degradedNotice)
        case .failed(let reason):
            OverlayStep(display: .notice(text(for: reason)), dissolveAfter: briefNotice)
        }
    }

    /// The whole cascade failed: the text was left on the pasteboard and
    /// the user finishes with a manual paste — action required.
    private static func notice(for state: DictationState) -> UserNotice? {
        guard case .failed(reason: .insertionFailed) = state else { return nil }
        return UserNotice(
            title: "Insertion failed", body: "Text copied — paste with ⌘V",
            identifier: "calamo.insertion-last-resort")
    }

    private static func text(for reason: FailureReason) -> String {
        switch reason {
        case .emptyDictation: "Nothing heard"
        case .secureField: "Secure field — dictation refused"
        case .transcriptionFailed: "Transcription failed"
        case .insertionFailed: "Insertion failed"
        case .micUnavailable: "Microphone unavailable"
        case .permissionRevoked: "Microphone access revoked"
        }
    }

    private static func text(for cause: RefusalCause) -> String {
        switch cause {
        case .engineLoading: "Models loading…"
        case .engineUnavailable(cause: .modelsMissing): "Models missing"
        case .pipelineBusy: "Still processing…"
        }
    }
}
