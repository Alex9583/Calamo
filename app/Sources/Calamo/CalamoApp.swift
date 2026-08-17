// Menu bar shell around the DictationEngine facade, all adapters live: the
// models load in the background while the engine gates dictation on Ready.
// AppKit lifecycle: the status item pulses and composes badges, which a
// MenuBarExtra label cannot render.
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
    private var onboarding: OnboardingController?
    private var store: ModelStore?

    static func main() {
        let app = NSApplication.shared
        EditMenu.install(into: app)
        let delegate = CalamoApp()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let trace = PipelineTrace.fromEnvironment
        let overlay = OverlayController()
        if let trace { overlay.onShown = { trace.recordPillShown() } }
        let menuBar = MenuBarController()
        menuBar.coldStart = UpdateDetection.coldStart()
        let transcription = DeferredTranscription()
        let store = ModelStore(root: ModelStoreLocation.root().path)
        let engine = Self.makeEngine(
            observer: makeObserver(menuBar: menuBar, overlay: overlay, trace: trace),
            transcription: transcription, store: store)
        menuBar.perform = { [weak self] in self?.perform($0) }
        menuBar.openSettings = { [weak self] in self?.showSettings() }
        (self.engine, self.menuBar, self.transcription) = (engine, menuBar, transcription)
        self.store = store
        startInput(sink: Self.makeSink(engine: engine, overlay: overlay, trace: trace))
        dictionaryWatcher = DictionaryHotReload.start(engine: engine)
        if OnboardingRecord.shouldShow() {
            showOnboarding()
        } else {
            MicrophoneGrant.requestIfUndetermined()
        }
        ModelLoader.start(
            engine: engine, transcription: transcription, store: store, download: downloadSink())
    }

    private func startInput(sink: DictationInputSink) {
        let input = PushToTalkInput(
            sink: sink,
            binding: HotkeyPreference.load(),
            captureDevice: { MicrophonePreference.currentDeviceID() })
        self.input = input
        if !input.start() {
            NSLog("Calamo: event tap unavailable — waiting for the Accessibility grant")
        }
        accessibilityPoll = AccessibilityPoll(input: input)
    }

    /// Before ModelLoader.start: the wizard must not miss the first
    /// download reports.
    private func showOnboarding() {
        let model = OnboardingModel()
        model.retryModels = { [weak self] in self?.reloadModels() }
        let controller = OnboardingController(model: model)
        onboarding = controller
        controller.show()
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
        guard let engine, let transcription, let store else { return }
        ModelLoader.start(
            engine: engine, transcription: transcription, store: store, download: downloadSink())
    }

    private func downloadSink() -> @Sendable (ModelDownloadProgress?) -> Void {
        { [weak self] progress in
            onMain {
                self?.menuBar?.downloadProgressChanged(progress)
                self?.onboarding?.model.downloadChanged(progress)
            }
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

    private func makeObserver(
        menuBar: MenuBarController, overlay: OverlayController, trace: PipelineTrace?
    ) -> DictationObserver {
        let relay = OnboardingRelay(
            wrapping: menuBar,
            onEngineState: { [weak self] state in
                onMain {
                    self?.onboarding?.model.engineChanged(state)
                    if state == .ready { self?.input?.prewarmCapture() }
                }
            },
            onDictationCompleted: { [weak self] in
                onMain { self?.onboarding?.model.dictationCompleted() }
            })
        let feedback = FeedbackObserver(
            wrapping: relay, overlay: overlay, coldStart: menuBar.coldStart)
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
}
