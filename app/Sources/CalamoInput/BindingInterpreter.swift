/// Maps raw tap events onto the machine's vocabulary for the current
/// binding. Chords fire only on transitions, so partial chords and unrelated
/// modifiers stay `.otherKey` and pass through untouched.
public struct BindingInterpreter: Sendable {
    public private(set) var binding: HotkeyBinding
    private var chordHeld = false

    public init(binding: HotkeyBinding) {
        self.binding = binding
    }

    public mutating func rebind(to binding: HotkeyBinding) {
        self.binding = binding
        chordHeld = false
    }

    public mutating func interpret(_ event: TapEvent) -> HotkeyEvent {
        switch event {
        case .tapDisabled:
            chordHeld = false
            return .tapDisabled
        case .flagsChanged(let keyCode, let modifiers, let fnDown):
            return interpretFlags(keyCode: keyCode, modifiers: modifiers, fnDown: fnDown)
        case .keyDown, .keyUp:
            return .otherKey
        }
    }

    private mutating func interpretFlags(
        keyCode: Int64, modifiers: HotkeyModifiers, fnDown: Bool
    ) -> HotkeyEvent {
        switch binding {
        case .fn:
            guard keyCode == KeyCode.fn else { return .otherKey }
            return .hotkeyChanged(isDown: fnDown)
        case .chord(let chord):
            let nowHeld = modifiers.isSuperset(of: chord)
            guard nowHeld != chordHeld else { return .otherKey }
            chordHeld = nowHeld
            return .hotkeyChanged(isDown: nowHeld)
        }
    }
}
