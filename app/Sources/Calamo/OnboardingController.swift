import AppKit
import SwiftUI

/// Owns the wizard window; closing it — Finish or the close button —
/// records the onboarding as done, never to be re-proposed.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
    let model: OnboardingModel
    private var window: NSWindow?

    init(model: OnboardingModel) {
        self.model = model
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(model: model, finish: { [weak self] in self?.window?.close() })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to Calamo"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        OnboardingRecord.markDone()
        model.stop()
    }
}
