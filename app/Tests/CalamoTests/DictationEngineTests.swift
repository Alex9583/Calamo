// Full dictation scenarios through the real generated bindings — foreign
// trait callbacks and observer events crossing the FFI both ways.
import CalamoCore
import Foundation
import Testing

final class ScriptedTranscription: TranscriptionPort, @unchecked Sendable {
    func transcribe(samples: [Float], boostList: [BoostEntry]) throws -> RawTranscript {
        RawTranscript(text: "pousse la branche sur github", language: .french)
    }
}

final class RecordingInsertion: InsertionPort, @unchecked Sendable {
    private let lock = NSLock()
    private var texts: [String] = []

    func insert(text: String) throws {
        lock.lock()
        texts.append(text)
        lock.unlock()
    }

    var insertedTexts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return texts
    }
}

final class TerminalObserver: DictationObserver, @unchecked Sendable {
    private let reachedTerminal = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var terminal: DictationState?

    func dictationStateChanged(dictation: UInt64, state: DictationState) {
        switch state {
        case .completed, .failed:
            lock.lock()
            terminal = state
            lock.unlock()
            reachedTerminal.signal()
        default:
            break
        }
    }

    func dictationRefused(cause: RefusalCause) {}

    func engineStateChanged(state: EngineState) {}

    func waitTerminal() -> DictationState? {
        guard reachedTerminal.wait(timeout: .now() + 2) == .success else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return terminal
    }
}

@Test func givenAReadyEngineWhenADictationIsSpokenThenTheVerbatimIsInsertedDegraded() {
    // Given
    let insertion = RecordingInsertion()
    let observer = TerminalObserver()
    let engine = DictationEngine(
        transcription: ScriptedTranscription(),
        insertion: insertion,
        observer: observer,
        config: EngineConfig(dictionaryPath: "", cleanupModelPath: "")
    )
    engine.markReady()

    // When
    engine.hotkeyPressed()
    engine.pushAudio(samples: [0.1, -0.2, 0.3])
    engine.hotkeyReleased()

    // Then
    #expect(observer.waitTerminal() == .completed(degraded: true))
    #expect(insertion.insertedTexts == ["pousse la branche sur github"])
}

final class RefusalObserver: DictationObserver, @unchecked Sendable {
    private let refused = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var cause: RefusalCause?

    func dictationStateChanged(dictation: UInt64, state: DictationState) {}
    func dictationRefused(cause: RefusalCause) {
        lock.lock()
        self.cause = cause
        lock.unlock()
        refused.signal()
    }
    func engineStateChanged(state: EngineState) {}

    func waitRefusal() -> RefusalCause? {
        guard refused.wait(timeout: .now() + 2) == .success else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return cause
    }
}

@Test func givenALoadingEngineWhenTheHotkeyIsPressedThenTheDictationIsRefusedAsEngineLoading() {
    // Given
    let observer = RefusalObserver()
    let engine = DictationEngine(
        transcription: ScriptedTranscription(),
        insertion: RecordingInsertion(),
        observer: observer,
        config: EngineConfig(dictionaryPath: "", cleanupModelPath: "")
    )

    // When
    engine.hotkeyPressed()

    // Then
    #expect(observer.waitRefusal() == .engineLoading)
}
