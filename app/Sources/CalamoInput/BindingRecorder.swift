/// Shortcut recorder fed by the live tap, so a recording can never start a
/// dictation. Accumulates held modifiers and captures the full set on the
/// first release; Fn captures alone; Escape cancels. Modifier events are
/// swallowed while recording, plain keys pass through.
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

    public init() {}

    public mutating func handle(_ event: TapEvent) -> Reaction {
        switch event {
        case .flagsChanged(let keyCode, let modifiers, let fnDown):
            let fnPressed = fnDown && keyCode == KeyCode.fn
            return Reaction(
                verdict: flagsVerdict(modifiers, fnPressed: fnPressed), swallowsEvent: true)
        case .keyDown(KeyCode.escape):
            return Reaction(verdict: .cancelled, swallowsEvent: true)
        case .keyDown, .keyUp:
            return Reaction(verdict: .recording, swallowsEvent: false)
        case .tapDisabled:
            return Reaction(verdict: .cancelled, swallowsEvent: false)
        }
    }

    private mutating func flagsVerdict(_ modifiers: HotkeyModifiers, fnPressed: Bool) -> Verdict {
        if fnPressed { return .captured(.fn) }
        if !accumulated.isEmpty, !modifiers.isSuperset(of: accumulated) {
            return .captured(.chord(accumulated))
        }
        accumulated.formUnion(modifiers)
        return .recording
    }
}
