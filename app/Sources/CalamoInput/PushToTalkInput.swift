import Foundation

/// Wires tap → machine → capture → sink. Tap callbacks stay instant: the
/// decision is pure, side effects run on a serial queue.
public final class PushToTalkInput {
    private let sink: DictationInputSink
    private let queue = DispatchQueue(label: "com.calamo.push-to-talk")
    private var machine = PushToTalkMachine()
    private var tap: FnKeyTap?
    private let capture = AudioCapture()

    public init(sink: DictationInputSink) {
        self.sink = sink
    }

    public func start() -> Bool {
        guard tap == nil else { return true }
        tap = FnKeyTap { [weak self] event in
            guard let self else { return .passthrough }
            let reaction = self.machine.handle(event)
            if !reaction.actions.isEmpty {
                self.queue.async { self.execute(reaction.actions) }
            }
            return reaction
        }
        return tap != nil
    }

    private func execute(_ actions: [HotkeyAction]) {
        for action in actions {
            switch action {
            case .beginDictation:
                sink.hotkeyPressed()
                startCapture()
            case .endDictation:
                let remainder = capture.stop()
                if !remainder.isEmpty { sink.pushAudio(samples: remainder) }
                sink.hotkeyReleased()
            case .reenableTap:
                tap?.reenable()
            }
        }
    }

    private func startCapture() {
        do {
            let sink = sink
            try capture.start { chunk in sink.pushAudio(samples: chunk) }
        } catch let failure as CaptureFailure {
            sink.captureFailed(failure)
        } catch {
            sink.captureFailed(.micUnavailable)
        }
    }
}
