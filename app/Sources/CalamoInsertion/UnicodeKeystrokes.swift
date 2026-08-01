import Carbon
import CoreGraphics

/// Types text as CGEvents bearing Unicode chunks; control characters go as
/// their own key presses (Return/Tab keycodes are layout-independent).
/// Inter-event delays keep slow apps from dropping events.
enum UnicodeKeystrokes {
    private static let interEventDelay: TimeInterval = 0.005

    static func type(_ segments: [KeystrokeSegment]) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        for segment in segments {
            guard post(segment, from: source) else { return false }
            Thread.sleep(forTimeInterval: interEventDelay)
        }
        return true
    }

    private static func post(_ segment: KeystrokeSegment, from source: CGEventSource) -> Bool {
        switch segment {
        case .text(let chunk):
            var units = Array(chunk.utf16)
            return postPress(of: 0, from: source) { event in
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            }
        case .key(let key):
            return postPress(of: keycode(for: key), from: source) { _ in }
        }
    }

    private static func postPress(
        of keyCode: CGKeyCode, from source: CGEventSource, prepare: (CGEvent) -> Void
    ) -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }
        prepare(keyDown)
        prepare(keyUp)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private static func keycode(for key: ControlKey) -> CGKeyCode {
        switch key {
        case .newline: CGKeyCode(kVK_Return)
        case .tab: CGKeyCode(kVK_Tab)
        }
    }
}
