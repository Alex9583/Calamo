// Menu bar shell around the DictationEngine facade, all adapters live: the
// models load in the background while the engine gates dictation on Ready.
import AVFoundation
import AppKit
import CalamoCore
import CalamoInput
import CalamoInsertion
import SwiftUI

/// Relays engine state to the menu bar; dictation events are rendered by
/// the FeedbackObserver upstream in the chain.
final class EngineStateModel: ObservableObject, DictationObserver, @unchecked Sendable {
    @Published var statusLabel = "Engine: loading…"

    func dictationStateChanged(dictation: UInt64, state: DictationState) {}

    func dictationRefused(cause: RefusalCause) {}

    func engineStateChanged(state: EngineState) {
        let label =
            switch state {
            case .loading: "Engine: loading…"
            case .ready: "Engine: ready"
            case .unavailable(.modelsMissing): "Engine: models missing"
            }
        DispatchQueue.main.async { self.statusLabel = label }
    }
}

@main
struct CalamoApp: App {
    private let engine: DictationEngine
    private let input: PushToTalkInput
    private let dictionaryWatcher: DictionaryWatcher
    @StateObject private var engineState: EngineStateModel

    init() {
        let trace = PipelineTrace.fromEnvironment
        let model = EngineStateModel()
        let overlay = OverlayController()
        let observer = Self.makeObserver(model: model, overlay: overlay, trace: trace)
        let transcription = DeferredTranscription()
        engine = DictationEngine(
            transcription: transcription,
            insertion: SimulatedPasteInsertion(),
            observer: observer,
            config: EngineConfig(
                dictionaryPath: DictionaryFile.url.path,
                cleanupModelPath: ModelLoader.cleanupModelPath()
            )
        )
        _engineState = StateObject(wrappedValue: model)
        input = PushToTalkInput(
            sink: Self.makeSink(engine: engine, overlay: overlay, trace: trace))
        dictionaryWatcher = DictionaryHotReload.start(engine: engine)
        Self.requestPermissions()
        if !input.start() {
            NSLog("Calamo: event tap unavailable — grant Accessibility, then relaunch")
        }
        ModelLoader.start(engine: engine, transcription: transcription)
    }

    private static func makeObserver(
        model: EngineStateModel, overlay: OverlayController, trace: PipelineTrace?
    ) -> DictationObserver {
        let feedback = FeedbackObserver(wrapping: model, overlay: overlay)
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

    var body: some Scene {
        MenuBarExtra("Calamo", systemImage: "waveform") {
            Text(engineState.statusLabel)
            Button("Dictionary…") {
                DictionaryFile.open()
            }
            Divider()
            Button("Quit Calamo") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
