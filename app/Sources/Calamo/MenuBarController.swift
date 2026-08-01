import AppKit
import CalamoCore
import CalamoFeedback

/// Engine changes arrive through the observer; permissions and secure input
/// have no event, so a poll keeps them fresh, plus a refresh whenever the
/// menu opens.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    var perform: (StatusAction) -> Void = { _ in }
    var openSettings: () -> Void = {}

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem()
    private var engine = EngineState.loading
    private var presentation: MenuBarPresentation?
    private var poll: Timer?
    private var pulse: Timer?
    private var pulseDimmed = false

    override init() {
        super.init()
        statusItem.menu = makeMenu()
        refresh()
        let poll = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            onMain { self?.refresh() }
        }
        RunLoop.main.add(poll, forMode: .common)
        self.poll = poll
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusLine.target = self
        statusLine.action = #selector(statusLineClicked)
        menu.addItem(statusLine)
        menu.addItem(item("Dictionary…", action: #selector(openDictionary)))
        menu.addItem(item("Settings…", action: #selector(settingsClicked)))
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit Calamo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    private func item(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func refresh() {
        let derived = MenuBarPresentation.derive(from: MenuBarProbes.snapshot(engine: engine))
        guard derived != presentation else { return }
        presentation = derived
        apply(derived)
    }

    private func apply(_ derived: MenuBarPresentation) {
        statusItem.button?.image = MenuBarIconRenderer.image(for: derived.icon)
        setPulsing(derived.icon == .loading)
        statusLine.title = derived.status.label
        statusLine.isEnabled = derived.status.action != nil
    }

    /// The pulse never reaches full opacity: dimmed and pulsing is the
    /// Loading rendition.
    private func setPulsing(_ active: Bool) {
        pulse?.invalidate()
        pulse = nil
        statusItem.button?.alphaValue = 1
        guard active else { return }
        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            onMain { self?.pulseStep() }
        }
        RunLoop.main.add(timer, forMode: .common)
        timer.fire()
        pulse = timer
    }

    private func pulseStep() {
        guard let button = statusItem.button else { return }
        pulseDimmed.toggle()
        let target: CGFloat = pulseDimmed ? 0.3 : 0.8
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.8
            button.animator().alphaValue = target
        }
    }

    @objc private func statusLineClicked() {
        guard let action = presentation?.status.action else { return }
        perform(action)
    }

    @objc private func openDictionary() {
        DictionaryFile.open()
    }

    @objc private func settingsClicked() {
        openSettings()
    }
}

extension MenuBarController: DictationObserver {
    nonisolated func dictationStateChanged(dictation: UInt64, state: DictationState) {}

    nonisolated func dictationRefused(cause: RefusalCause) {}

    nonisolated func engineStateChanged(state: EngineState) {
        onMain {
            self.engine = state
            self.refresh()
        }
    }
}
