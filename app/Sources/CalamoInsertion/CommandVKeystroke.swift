import CoreGraphics
import Foundation

/// Posts the synthetic Cmd-V. Event-source or event allocation can fail
/// transiently, hence the retries; CGEventPost itself reports nothing.
enum CommandVKeystroke {
    static func post() -> Bool {
        let keyCode = PasteKeycode.commandV()
        for attempt in 0..<3 {
            if attempt > 0 {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if postOnce(keyCode) {
                return true
            }
        }
        return false
    }

    private static func postOnce(_ keyCode: CGKeyCode) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
