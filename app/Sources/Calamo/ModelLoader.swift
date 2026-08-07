import CalamoCore
import CalamoFeedback
import CalamoTranscription
import Foundation

/// Drives the cold start: the ModelStore installs and verifies the pinned
/// catalog, then the models load. A failed cleanup load is tolerated
/// (dictations degrade); the store outcome and the ASR load are the
/// engine's availability.
enum ModelLoader {
    private static let lock = NSLock()
    // Guarded by `lock`; one run at a time — a second click mid-download
    // would race the same partial files.
    nonisolated(unsafe) private static var active = false

    static func cleanupModelPath(store: ModelStore) -> String {
        ProcessInfo.processInfo.environment["CALAMO_CLEANUP_GGUF"] ?? store.paths().cleanupGguf
    }

    /// The blocking store and loads run on a dedicated plain thread — never
    /// the cooperative pool, which the transcription adapter's sync bridge
    /// forbids.
    static func start(
        engine: DictationEngine, transcription: DeferredTranscription, store: ModelStore,
        download: @escaping @Sendable (ModelDownloadProgress?) -> Void
    ) {
        guard begin() else { return }
        engine.markLoading()
        Thread.detachNewThread {
            defer { end() }
            guard ensure(store: store, download: download) else {
                engine.markUnavailable(cause: .modelsMissing)
                return
            }
            loadCleanup(engine: engine)
            loadTranscription(engine: engine, transcription: transcription, store: store)
        }
    }

    private static func ensure(
        store: ModelStore, download: @escaping @Sendable (ModelDownloadProgress?) -> Void
    ) -> Bool {
        defer { download(nil) }
        do {
            try store.ensure(observer: DownloadForwarder(download))
            return true
        } catch {
            NSLog("Calamo: model store failed: %@", String(describing: error))
            return false
        }
    }

    private static func loadCleanup(engine: DictationEngine) {
        do {
            try engine.loadCleanup()
        } catch {
            NSLog(
                "Calamo: cleanup model not loaded — dictations will degrade: %@",
                String(describing: error))
        }
    }

    private static func loadTranscription(
        engine: DictationEngine, transcription: DeferredTranscription, store: ModelStore
    ) {
        let paths = store.paths()
        do {
            transcription.install(
                try FluidAudioTranscription.load(
                    paths: TranscriptionModelPaths(
                        asrModels: URL(fileURLWithPath: paths.asrTdtDir),
                        ctcModels: URL(fileURLWithPath: paths.asrCtcDir))))
            engine.markReady()
            UpdateDetection.recordCompiled()
        } catch {
            NSLog("Calamo: ASR models failed to load: %@", String(describing: error))
            engine.markUnavailable(cause: .modelsMissing)
        }
    }

    private static func begin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if active { return false }
        active = true
        return true
    }

    private static func end() {
        lock.lock()
        defer { lock.unlock() }
        active = false
    }
}

private final class DownloadForwarder: ModelStoreObserver, @unchecked Sendable {
    private let forward: @Sendable (ModelDownloadProgress?) -> Void

    init(_ forward: @escaping @Sendable (ModelDownloadProgress?) -> Void) {
        self.forward = forward
    }

    func modelsReady(ready: UInt32, total: UInt32) {
        forward(ModelDownloadProgress(ready: Int(ready), total: Int(total)))
    }
}
