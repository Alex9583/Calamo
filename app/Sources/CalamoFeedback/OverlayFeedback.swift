// The overlay vocabulary the AppKit glue renders without interpretation.
import Foundation

public enum OverlayDisplay: Equatable, Sendable {
    case hidden
    case waveform
    case waiting
    case notice(String)
}

public struct OverlayStep: Equatable, Sendable {
    public let display: OverlayDisplay
    /// nil: the display holds until the next event.
    public let dissolveAfter: TimeInterval?
    /// Shown when dissolveAfter elapses; nil dissolves to hidden. Lets a
    /// refusal notice give the pill back to a still-running dictation.
    public let revertsTo: OverlayDisplay?

    public init(
        display: OverlayDisplay, dissolveAfter: TimeInterval? = nil,
        revertsTo: OverlayDisplay? = nil
    ) {
        self.display = display
        self.dissolveAfter = dissolveAfter
        self.revertsTo = revertsTo
    }
}

public enum SoundCue: Equatable, Sendable {
    case captureStart
    case captureEnd
}

public struct FeedbackReaction: Equatable, Sendable {
    public let step: OverlayStep
    public let sound: SoundCue?

    public init(step: OverlayStep, sound: SoundCue?) {
        self.step = step
        self.sound = sound
    }
}
