/// Shortcut recorder fed by the live tap, so a recording can never start a
/// dictation. Fn's press or a chord's first release decides; the verdict
/// waits for the full release, flags swallowed until then — a leak would
/// desync or trigger the frontmost app. The swallow cannot stop the 🌐
/// action: macOS decides a brief Fn press ahead of the tap.
public struct BindingRecorder: Sendable {
    public enum Verdict: Equatable, Sendable {
        case recording
        case captured(HotkeyBinding)
        case cancelled
    }

    public struct Reaction: Equatable, Sendable {
        public let verdict: Verdict
        public let swallowsEvent: Bool

        public init(verdict: Verdict, swallowsEvent: Bool) {
            self.verdict = verdict
            self.swallowsEvent = swallowsEvent
        }
    }

    private var accumulated = HotkeyModifiers()
    private var held = HotkeyModifiers()
    private var fnHeld = false
    private var decision: Verdict?

    public init() {}

    public mutating func handle(_ event: TapEvent) -> Reaction {
        switch event {
        case .flagsChanged(let keyCode, let modifiers, let fnDown):
            held = modifiers
            fnHeld = fnDown
            if decision == nil { decision = captureDecision(keyCode: keyCode) }
            if decision == nil { accumulated.formUnion(held) }
            return Reaction(verdict: settledVerdict, swallowsEvent: true)
        case .keyDown(KeyCode.escape):
            decision = .cancelled
            return Reaction(verdict: settledVerdict, swallowsEvent: true)
        case .keyDown, .keyUp:
            return Reaction(verdict: .recording, swallowsEvent: false)
        case .tapDisabled:
            return Reaction(verdict: decision ?? .cancelled, swallowsEvent: false)
        }
    }

    private func captureDecision(keyCode: Int64) -> Verdict? {
        if fnHeld, keyCode == KeyCode.fn { return .captured(.fn) }
        guard !accumulated.isEmpty, !held.isSuperset(of: accumulated) else { return nil }
        return .captured(.chord(accumulated))
    }

    private var settledVerdict: Verdict {
        guard let decision, held.isEmpty, !fnHeld else { return .recording }
        return decision
    }
}
