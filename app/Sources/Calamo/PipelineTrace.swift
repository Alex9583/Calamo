import CalamoCore
import Foundation

/// Walking-skeleton instrumentation, enabled by CALAMO_TRACE=1: every engine
/// event to stderr with a monotonic timestamp, plus per-dictation FFI push
/// overhead and release→terminal latency.
final class PipelineTrace: @unchecked Sendable {
    static let fromEnvironment: PipelineTrace? =
        ProcessInfo.processInfo.environment["CALAMO_TRACE"] == "1" ? PipelineTrace() : nil

    private let started = DispatchTime.now()
    private let lock = NSLock()
    private var pushSeconds = 0.0
    private var pushChunks = 0
    private var captureOpen = false
    private var released: [DispatchTime] = []

    func measurePush(_ push: () -> Void) {
        let start = DispatchTime.now()
        push()
        let elapsed = Self.seconds(from: start, to: .now())
        lock.withLock {
            pushSeconds += elapsed
            pushChunks += 1
        }
    }

    /// A release without an open capture (refused press) times no dictation.
    func recordRelease() {
        let (seconds, chunks, open) = lock.withLock {
            let open = captureOpen
            if open {
                captureOpen = false
                released.append(.now())
            }
            defer {
                pushSeconds = 0
                pushChunks = 0
            }
            return (pushSeconds, pushChunks, open)
        }
        let tag = open ? "" : " (no dictation)"
        log(
            String(
                format: "released%@ — %d chunks, %.2f ms in push_audio",
                tag, chunks, seconds * 1000))
    }

    func dictationStateChanged(dictation: UInt64, state: DictationState) {
        switch state {
        case .capturing:
            lock.withLock { captureOpen = true }
            log("dictation \(dictation) → \(state)")
        case .completed, .failed:
            log("dictation \(dictation) → \(state)\(latencySuffix())")
        default:
            log("dictation \(dictation) → \(state)")
        }
    }

    func dictationRefused(cause: RefusalCause) {
        log("refused — \(cause)")
    }

    func engineStateChanged(state: EngineState) {
        log("engine → \(state)")
    }

    /// Terminal states pop releases in order — the engine inserts in release
    /// order, so the oldest release is this dictation's.
    private func latencySuffix() -> String {
        let release = lock.withLock { () -> DispatchTime? in
            guard !released.isEmpty else {
                // Terminal before any release: capture failure — close the
                // capture so the inert release that follows records nothing.
                captureOpen = false
                return nil
            }
            return released.removeFirst()
        }
        guard let release else { return "" }
        return String(format: " — %.2f s after release", Self.seconds(from: release, to: .now()))
    }

    private func log(_ message: String) {
        let elapsed = Self.seconds(from: started, to: .now())
        let line = String(format: "[trace +%8.3fs] %@\n", elapsed, message)
        FileHandle.standardError.write(Data(line.utf8))
    }

    private static func seconds(from: DispatchTime, to: DispatchTime) -> Double {
        Double(to.uptimeNanoseconds - from.uptimeNanoseconds) / 1_000_000_000
    }
}
