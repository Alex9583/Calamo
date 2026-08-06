// Menu bar shell around the DictationEngine facade, all adapters live: the
// models load in the background while the engine gates dictation on Ready.
// AppKit lifecycle: the status item pulses and composes badges, which a
// MenuBarExtra label cannot render.
import AVFoundation
import AppKit
import CalamoCore
import CalamoFeedback
import CalamoInput
import CalamoInsertion

@main
@MainActor
final class CalamoApp: NSObject, NSApplicationDelegate {
    private var engine: DictationEngine?
    private var input: PushToTalkInput?
    private var accessibilityPoll: AccessibilityPoll?
    private var transcription: DeferredTranscription?
    private var dictionaryWatcher: DictionaryWatcher?
    private var menuBar: MenuBarController?
    private var settings: SettingsController?
    private var store: ModelStore?

    static func main() {
        let app = NSApplication.shared
        let delegate = CalamoApp()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let trace = PipelineTrace.fromEnvironment
        let overlay = OverlayController()
        let menuBar = MenuBarController()
        let transcription = DeferredTranscription()
        let store = ModelStore(root: ModelStoreLocation.root().path)
        let engine = Self.makeEngine(
            observer: Self.makeObserver(menuBar: menuBar, overlay: overlay, trace: trace),
            transcription: transcription, store: store)
        menuBar.perform = { [weak self] in self?.perform($0) }
        menuBar.openSettings = { [weak self] in self?.showSettings() }
        (self.engine, self.menuBar, self.transcription) = (engine, menuBar, transcription)
        self.store = store
        input = PushToTalkInput(
            sink: Self.makeSink(engine: engine, overlay: overlay, trace: trace),
            binding: HotkeyPreference.load(),
            captureDevice: { MicrophonePreference.currentDeviceID() })
        dictionaryWatcher = DictionaryHotReload.start(engine: engine)
        Self.requestPermissions()
        if input?.start() != true {
            NSLog("Calamo: event tap unavailable — waiting for the Accessibility grant")
        }
        if let input { accessibilityPoll = AccessibilityPoll(input: input) }
        ModelLoader.start(
            engine: engine, transcription: transcription, store: store,
            download: Self.downloadSink(menuBar: menuBar))
    }

    private func showSettings() {
        guard let input else { return }
        if settings == nil { settings = SettingsController(input: input) }
        settings?.show()
    }

    private func perform(_ action: StatusAction) {
        switch action {
        case .openAccessibilitySettings: SystemSettings.openAccessibility()
        case .openMicrophoneSettings: SystemSettings.openMicrophone()
        case .redownloadModels: reloadModels()
        }
    }

    private func reloadModels() {
        guard let engine, let transcription, let store, let menuBar else { return }
        ModelLoader.start(
            engine: engine, transcription: transcription, store: store,
            download: Self.downloadSink(menuBar: menuBar))
    }

    private static func downloadSink(
        menuBar: MenuBarController
    ) -> @Sendable (ModelDownloadProgress?) -> Void {
        { [weak menuBar] progress in
            onMain { menuBar?.downloadProgressChanged(progress) }
        }
    }

    private static func makeEngine(
        observer: DictationObserver, transcription: DeferredTranscription, store: ModelStore
    ) -> DictationEngine {
        DictationEngine(
            transcription: transcription,
            insertion: CascadeInsertion(),
            observer: observer,
            config: EngineConfig(
                dictionaryPath: DictionaryFile.url.path,
                cleanupModelPath: ModelLoader.cleanupModelPath(store: store)))
    }

    private static func makeObserver(
        menuBar: MenuBarController, overlay: OverlayController, trace: PipelineTrace?
    ) -> DictationObserver {
        let feedback = FeedbackObserver(wrapping: menuBar, overlay: overlay)
        guard let trace else { return feedback }
        return TracingObserver(wrapping: feedback, trace: trace)
    }

    private static func makeSink(
        engine: DictationEngine, overlay: OverlayController, trace: PipelineTrace?
    ) -> DictationInputSink {
        var sink: DictationInputSink = EngineInputSink(engine: engine)
        if let trace {
            sink = TracingInputSink(wrapping: sink, trace: trace)
        }
        if ProcessInfo.processInfo.environment["CALAMO_INPUT_DEMO"] == "1" {
            sink = InstrumentedInputSink(wrapping: sink)
        }
        return LevelMeteringInputSink(wrapping: sink) { level in
            onMain { overlay.push(level: level) }
        }
    }

    // Interim flow until onboarding (ticket 20) walks the user through TCC.
    private static func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        // kAXTrustedCheckOptionPrompt is a C global `var` Swift 6 rejects;
        // its literal value is API.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
