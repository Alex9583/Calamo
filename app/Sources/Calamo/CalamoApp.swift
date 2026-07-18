// Menu bar shell around the DictationEngine facade. Real adapters land with
// tickets 06/08/09; until then the ports are inert and the engine stays Loading.
import AppKit
import CalamoCore
import SwiftUI

/// Fails every transcription until ticket 06 wires FluidAudio.
final class TranscriptionNotWired: TranscriptionPort, @unchecked Sendable {
    func transcribe(samples: [Float], boostList: [BoostEntry]) throws -> RawTranscript {
        throw TranscriptionError.Failed(message: "transcription adapter not wired yet (ticket 06)")
    }
}

/// Fails every insertion until ticket 09 wires the simulated paste.
final class InsertionNotWired: InsertionPort, @unchecked Sendable {
    func insert(text: String) throws {
        throw InsertionError.Failed(message: "insertion adapter not wired yet (ticket 09)")
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
    @StateObject private var engineState: EngineStateModel

    init() {
        let model = EngineStateModel()
        engine = DictationEngine(
            transcription: TranscriptionNotWired(),
            insertion: InsertionNotWired(),
            observer: model,
            // Consumed by the core's internal adapters at tickets 07/12.
            config: EngineConfig(dictionaryPath: "", cleanupModelPath: "")
        )
        _engineState = StateObject(wrappedValue: model)
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
