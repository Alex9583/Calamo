// The engine exactly as the app assembles it, with the two shell adapters
// the e2e suite cannot use doubled: insertion captured, observer awaited.
import CalamoCore
import CalamoTranscription
import Foundation

struct E2eStack {
    enum DictationOutcome: Error {
        case timedOut
        case notCompleted(DictationState)
        case degraded
        case nothingInserted
    }

    let engine: DictationEngine
    let insertion: CapturingInsertion
    let observer: TerminalObserver
    let dictionaryURL: URL

    static func load(dictionary: String) throws -> E2eStack {
        let insertion = CapturingInsertion()
        let observer = TerminalObserver()
        let dictionaryURL = try writtenDictionary(dictionary)
        let engine = DictationEngine(
            transcription: try FluidAudioTranscription.load(paths: .defaultCache()),
            insertion: insertion,
            observer: observer,
            config: EngineConfig(dictionaryPath: dictionaryURL.path, cleanupModelPath: ggufPath()))
        try engine.loadCleanup()
        engine.markReady()
        return E2eStack(
            engine: engine, insertion: insertion, observer: observer, dictionaryURL: dictionaryURL)
    }

    /// The user's hot edit: save the TOML, the shell relays the change.
    func editDictionary(_ toml: String) throws {
        try toml.write(to: dictionaryURL, atomically: true, encoding: .utf8)
        try engine.reloadDictionary()
    }

    private static func writtenDictionary(_ toml: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("calamo-e2e-\(UUID().uuidString)")
            .appendingPathComponent("dictionary.toml")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try toml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func ggufPath() -> String {
        ProcessInfo.processInfo.environment["CALAMO_CLEANUP_GGUF"]
            ?? GoldenFixtures.directory.appendingPathComponent("models/Qwen3.5-2B-Q4_K_M.gguf").path
    }

    func dictate(_ samples: [Float]) throws -> String {
        engine.hotkeyPressed()
        var start = 0
        while start < samples.count {
            let end = min(start + 1600, samples.count)
            engine.pushAudio(samples: Array(samples[start..<end]))
            start = end
        }
        engine.hotkeyReleased()
        guard let state = observer.awaitTerminal(seconds: 120) else {
            throw DictationOutcome.timedOut
        }
        guard case .completed(let degraded) = state else {
            throw DictationOutcome.notCompleted(state)
        }
        guard !degraded else { throw DictationOutcome.degraded }
        guard let text = insertion.takeLast() else { throw DictationOutcome.nothingInserted }
        return text
    }
}

final class CapturingInsertion: InsertionPort, @unchecked Sendable {
    private let lock = NSLock()
    private var texts: [String] = []

    func insert(text: String) throws {
        lock.withLock { texts.append(text) }
    }

    func takeLast() -> String? {
        lock.withLock { texts.popLast() }
    }
}

final class TerminalObserver: DictationObserver, @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var terminals: [DictationState] = []

    func dictationStateChanged(dictation: UInt64, state: DictationState) {
        switch state {
        case .completed, .failed:
            lock.withLock { terminals.append(state) }
            semaphore.signal()
        default:
            break
        }
    }

    /// A refusal means no terminal state will ever come: surface it as one.
    func dictationRefused(cause: RefusalCause) {
        lock.withLock { terminals.append(.failed(reason: .emptyDictation)) }
        print("[e2e-golden] dictation refused: \(cause)")
        semaphore.signal()
    }

    func engineStateChanged(state: EngineState) {}

    func awaitTerminal(seconds: Double) -> DictationState? {
        guard semaphore.wait(timeout: .now() + seconds) == .success else { return nil }
        return lock.withLock { terminals.isEmpty ? nil : terminals.removeFirst() }
    }
}
