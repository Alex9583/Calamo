import CalamoCore
import CalamoTranscription
import Foundation

/// Loads the models at startup and reports engine availability. Interim
/// locations until the ModelStore (ticket 19): FluidAudio's cache for ASR,
/// the repo's fixtures GGUF for cleanup.
enum ModelLoader {
    static func cleanupModelPath() -> String {
        if let override = ProcessInfo.processInfo.environment["CALAMO_CLEANUP_GGUF"] {
            return override
        }
        // build/Calamo.app sits two levels below the repo root.
        return Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures/models/Qwen3.5-2B-Q4_K_M.gguf")
            .path
    }

    /// Both loads block, so they run on a dedicated plain thread — never the
    /// cooperative pool, which the transcription adapter's sync bridge
    /// forbids. A failed cleanup load is tolerated (dictations degrade); ASR
    /// models are the engine's availability.
    static func start(engine: DictationEngine, transcription: DeferredTranscription) {
        Thread.detachNewThread {
            do {
                try engine.loadCleanup()
            } catch {
                NSLog("Calamo: cleanup model not loaded — dictations will degrade: \(error)")
            }
            do {
                transcription.install(try FluidAudioTranscription.load(paths: .defaultCache()))
                engine.markReady()
            } catch {
                NSLog("Calamo: ASR models failed to load: \(error)")
                engine.markUnavailable(cause: .modelsMissing)
            }
        }
    }
}
