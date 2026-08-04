import CoreAudio
import Foundation

/// Wires tap → interpreter → machine → capture → sink, or tap → recorder
/// while a shortcut is being recorded. Tap callbacks stay instant: the
/// decision is pure, side effects run on a serial queue.
///
/// @unchecked: `machine`, `interpreter`, `recording` and `tap` are
/// main-run-loop confined (start/stop/sync, rebind, recording control +
/// tap callbacks; `execute` hops back for the tap), `capture` is confined
/// to the serial queue.
public final class PushToTalkInput: @unchecked Sendable {
    private let sink: DictationInputSink
    private let queue = DispatchQueue(label: "com.calamo.push-to-talk")
    private var machine = PushToTalkMachine()
    private var interpreter: BindingInterpreter
    private var recording:
        (recorder: BindingRecorder, onVerdict: (BindingRecorder.Verdict) -> Void)?
    private var tap: HotkeyTap?
    private let capture = AudioCapture()
    private let captureDevice: @Sendable () -> AudioDeviceID?

    public init(
        sink: DictationInputSink, binding: HotkeyBinding,
        captureDevice: @escaping @Sendable () -> AudioDeviceID?
    ) {
        self.sink = sink
        self.interpreter = BindingInterpreter(binding: binding)
        self.captureDevice = captureDevice
    }

    public func start() -> Bool {
        guard tap == nil else { return true }
        tap = HotkeyTap { [weak self] event in
            self?.handle(event) ?? false
        }
        return tap != nil
    }

    /// An in-flight hold ends as if released — its release could never
    /// arrive through a dead tap.
    public func stop() {
        forceEndHold()
        tap?.invalidate()
        tap = nil
    }

    /// Poll-driven: the tap's existence follows the Accessibility grant;
    /// a failed recreate retries on the next poll.
    public func syncTap(trusted: Bool) {
        switch TapGuard.reconcile(trusted: trusted, tapActive: tap != nil) {
        case .recreate: _ = start()
        case .tearDown: stop()
        case .keep: break
        }
    }

    /// Takes effect on the very next tap event; an in-flight hold ends now —
    /// its release would be invisible to the new binding.
    public func rebind(to binding: HotkeyBinding) {
        forceEndHold()
        interpreter.rebind(to: binding)
    }

    /// Routes tap events to a fresh recorder until it captures or cancels;
    /// an in-flight hold ends now and no dictation can start meanwhile.
    public func beginBindingRecording(onVerdict: @escaping (BindingRecorder.Verdict) -> Void) {
        forceEndHold()
        recording = (BindingRecorder(), onVerdict)
    }

    public func cancelBindingRecording() {
        recording = nil
    }

    private func forceEndHold() {
        let reaction = machine.handle(.hotkeyChanged(isDown: false))
        if !reaction.actions.isEmpty {
            queue.async { self.execute(reaction.actions) }
        }
    }

    private func handle(_ event: TapEvent) -> Bool {
        if recording != nil { return handleRecording(event) }
        let reaction = machine.handle(interpreter.interpret(event))
        if !reaction.actions.isEmpty {
            queue.async { self.execute(reaction.actions) }
        }
        return reaction.swallowsEvent && interpreter.binding.swallowsEvents
    }

    private func handleRecording(_ event: TapEvent) -> Bool {
        guard let reaction = recording?.recorder.handle(event) else { return false }
        guard reaction.verdict != .recording, let onVerdict = recording?.onVerdict else {
            return reaction.swallowsEvent
        }
        recording = nil
        if event == .tapDisabled { tap?.reenable() }
        onVerdict(reaction.verdict)
        return reaction.swallowsEvent
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
                DispatchQueue.main.async { self.tap?.reenable() }
            }
        }
    }

    private func startCapture() {
        do {
            let sink = sink
            try capture.start(deviceID: captureDevice()) { chunk in sink.pushAudio(samples: chunk) }
        } catch let failure as CaptureFailure {
            sink.captureFailed(failure)
        } catch {
            sink.captureFailed(.micUnavailable)
        }
    }
}
