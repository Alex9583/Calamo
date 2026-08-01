import AppKit
import CalamoInput
import SwiftUI

/// Owns the single settings window; the model lives across closes so a
/// reopened window shows current state instantly.
@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private var window: NSWindow?

    init(input: PushToTalkInput) {
        model = SettingsModel(input: input)
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        model.refresh()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Calamo Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    /// A recording must not outlive the window that started it.
    func windowWillClose(_ notification: Notification) {
        model.cancelRecording()
    }

    /// A keyboard plugged in while the window was open surfaces its
    /// proposal as soon as the user comes back.
    func windowDidBecomeKey(_ notification: Notification) {
        model.refresh()
    }
}
