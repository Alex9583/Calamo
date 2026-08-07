import AppKit

enum SystemSettings {
    static func openAccessibility() { open("Privacy_Accessibility") }
    static func openMicrophone() { open("Privacy_Microphone") }

    static func openKeyboard() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
        else { return }
        NSWorkspace.shared.open(url)
    }

    private static func open(_ pane: String) {
        guard
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
