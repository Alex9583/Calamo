import CalamoCore
import CalamoFeedback
import Foundation

/// @unchecked: `machine` is lock-protected; the overlay and sounds only run
/// on the main queue.
final class FeedbackObserver: DictationObserver, @unchecked Sendable {
    private let wrapped: DictationObserver
    private let overlay: OverlayController
    private let sounds = DictationSounds()
    private let lock = NSLock()
    private var machine = FeedbackMachine()

    init(wrapping wrapped: DictationObserver, overlay: OverlayController) {
        self.wrapped = wrapped
        self.overlay = overlay
    }

    func dictationStateChanged(dictation: UInt64, state: DictationState) {
        react { $0.handle(state) }
        wrapped.dictationStateChanged(dictation: dictation, state: state)
    }

    func dictationRefused(cause: RefusalCause) {
        react { $0.handle(refusal: cause) }
        wrapped.dictationRefused(cause: cause)
    }

    func engineStateChanged(state: EngineState) {
        wrapped.engineStateChanged(state: state)
    }

    private func react(_ handle: (inout FeedbackMachine) -> FeedbackReaction) {
        lock.lock()
        let reaction = handle(&machine)
        lock.unlock()
        onMain {
            if let sound = reaction.sound { self.sounds.play(sound) }
            self.overlay.apply(reaction.step)
        }
    }
}
