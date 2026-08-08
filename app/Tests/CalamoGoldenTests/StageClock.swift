// Stamps the pipeline's observer callbacks and the doubled insertion on one
// monotonic clock. The harness dictates strictly one at a time, so a single
// stamp slate per dictation suffices; noteReleased wipes it.
import CalamoCore
import Foundation

final class StageClock: DictationObserver, @unchecked Sendable {
    struct Slate {
        var released: UInt64?
        var transcribing: UInt64?
        var cleaning: UInt64?
        var inserting: UInt64?
        var inserted: UInt64?

        var stamps: StageStamps? {
            guard let released, let transcribing, let cleaning, let inserting, let inserted
            else { return nil }
            return StageStamps(
                released: released, transcribing: transcribing, cleaning: cleaning,
                inserting: inserting, inserted: inserted)
        }
    }

    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var slate = Slate()
    private var terminal: DictationState?

    func noteReleased() {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.withLock {
            slate = Slate(released: now)
            terminal = nil
        }
    }

    func noteInserted() {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.withLock { slate.inserted = now }
    }

    func dictationStateChanged(dictation: UInt64, state: DictationState) {
        let now = DispatchTime.now().uptimeNanoseconds
        switch state {
        case .transcribing: lock.withLock { slate.transcribing = now }
        case .cleaning: lock.withLock { slate.cleaning = now }
        case .inserting: lock.withLock { slate.inserting = now }
        case .completed, .failed:
            lock.withLock { terminal = state }
            semaphore.signal()
        default: break
        }
    }

    /// A refusal means no terminal state will ever come: surface it as one.
    func dictationRefused(cause: RefusalCause) {
        print("[perf] dictation refused: \(cause)")
        lock.withLock { terminal = .failed(reason: .emptyDictation) }
        semaphore.signal()
    }

    func engineStateChanged(state: EngineState) {}

    func awaitOutcome(seconds: Double) -> (DictationState, Slate)? {
        guard semaphore.wait(timeout: .now() + seconds) == .success else { return nil }
        return lock.withLock { terminal.map { ($0, slate) } }
    }
}

final class StampingInsertion: InsertionPort, @unchecked Sendable {
    private let clock: StageClock

    init(clock: StageClock) {
        self.clock = clock
    }

    func insert(text: String) throws {
        clock.noteInserted()
    }
}
