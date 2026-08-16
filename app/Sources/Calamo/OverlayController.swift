import AppKit
import CalamoFeedback
import SwiftUI

/// Thin renderer of OverlaySteps: shows, dissolves and repositions the pill;
/// what to show was decided in CalamoFeedback.
@MainActor
final class OverlayController {
    var onShown: (() -> Void)?
    private let panel = OverlayPanel()
    private let model = OverlayModel()
    private var dissolve: Timer?
    /// Bumped on every show/hide so a stale fade-out completion never
    /// orders out a pill a newer event just showed.
    private var generation = 0

    init() {
        let hosting = NSHostingView(rootView: OverlayView(model: model))
        // Never let SwiftUI size the panel: the preferred size computed on
        // a hidden→notice flip shrinks the window before the text is
        // measured, freezing the pill as an empty 36×40 capsule. The panel
        // is sized before the view attaches — attaching resizes the view
        // to the panel, never the other way around.
        hosting.sizingOptions = []
        panel.setContentSize(NSSize(width: 420, height: 80))
        panel.contentView = hosting
    }

    func apply(_ step: OverlayStep) {
        dissolve?.invalidate()
        dissolve = nil
        guard step.display != .hidden else { return hide() }
        model.show(step.display)
        show()
        if let delay = step.dissolveAfter {
            scheduleDissolve(after: delay, revertingTo: step.revertsTo)
        }
    }

    func push(level: Float) {
        model.push(level: level)
    }

    /// Pays the pill's first-show costs — window-server window, SwiftUI
    /// graph, fonts — invisibly, so the first press renders it warm. A pill
    /// already on screen paid them itself.
    func prewarm() {
        guard model.display == .hidden else { return }
        model.show(.waveform)
        panel.alphaValue = 0
        position()
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        panel.orderOut(nil)
        model.show(.hidden)
    }

    private func scheduleDissolve(after delay: TimeInterval, revertingTo revert: OverlayDisplay?) {
        dissolve = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            onMain {
                if let revert { self.model.show(revert) } else { self.hide() }
            }
        }
    }

    private func show() {
        generation += 1
        position()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 1
        }
        panel.orderFrontRegardless()
        onShown?()
    }

    private func hide() {
        generation += 1
        let fade = generation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                guard self.generation == fade else { return }
                self.panel.orderOut(nil)
                self.model.show(.hidden)
            }
        }
    }

    private func position() {
        guard let screen = FocusedScreen.current() else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 24))
    }
}
