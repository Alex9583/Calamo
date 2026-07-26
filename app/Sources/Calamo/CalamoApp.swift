// Menu bar shell around the DictationEngine facade. Push-to-talk input and
// insertion are live; transcription stays inert — and the engine Loading —
// until ticket 10 wires the FluidAudio adapter.
import AVFoundation
import AppKit
import CalamoCore
import CalamoInput
import CalamoInsertion
import SwiftUI

/// Fails every transcription until ticket 10 wires the FluidAudio adapter.
final class TranscriptionNotWired: TranscriptionPort, @unchecked Sendable {
    func transcribe(samples: [Float], boostList: [BoostEntry]) throws -> RawTranscript {
        throw TranscriptionError.Failed(message: "transcription adapter not wired yet (ticket 10)")
    }
}

/// Relays engine state to the menu bar; other events get their UI at ticket 14.
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
    @StateObject private var engineState: EngineStateModel

    init() {
        let model = EngineStateModel()
        engine = DictationEngine(
            transcription: TranscriptionNotWired(),
            insertion: SimulatedPasteInsertion(),
            observer: model,
            // Consumed by the core's internal adapters at tickets 10/12.
            config: EngineConfig(dictionaryPath: "", cleanupModelPath: "")
        )
        _engineState = StateObject(wrappedValue: model)
        input = PushToTalkInput(sink: Self.makeSink(engine: engine))
        Self.requestPermissions()
        if !input.start() {
            NSLog("Calamo: event tap unavailable — grant Accessibility, then relaunch")
        }
    }

    private static func makeSink(engine: DictationEngine) -> DictationInputSink {
        let sink = EngineInputSink(engine: engine)
        return ProcessInfo.processInfo.environment["CALAMO_INPUT_DEMO"] == "1"
            ? InstrumentedInputSink(wrapping: sink) : sink
    }

    // Interim flow until onboarding (ticket 20) walks the user through TCC.
    private static func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    var body: some Scene {
        MenuBarExtra("Calamo", systemImage: "waveform") {
            Text(engineState.statusLabel)
            Divider()
            Button("Quit Calamo") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
