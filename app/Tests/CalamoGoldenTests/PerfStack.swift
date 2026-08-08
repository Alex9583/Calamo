// The e2e assembly instrumented for latency: same engine as E2eStack, with
// the observer and the doubled insertion feeding one StageClock.
import CalamoCore
import Foundation

struct PerfStack {
    enum PerfOutcome: Error {
        case timedOut
        case notCompleted(DictationState)
        case degraded
        case stampsMissing
    }

    let engine: DictationEngine
    let clock: StageClock

    static func load(dictionary: String) throws -> PerfStack {
        let clock = StageClock()
        let engine = try E2eStack.loadedEngine(
            dictionaryURL: E2eStack.writtenDictionary(dictionary),
            insertion: StampingInsertion(clock: clock),
            observer: clock)
        return PerfStack(engine: engine, clock: clock)
    }

    /// Release is stamped just before the FFI call: the hotkeyReleased
    /// crossing itself is user-visible latency, so it counts.
    func dictate(_ samples: [Float]) throws -> PerfMeasure {
        engine.hotkeyPressed()
        E2eStack.feed(samples, into: engine)
        clock.noteReleased()
        engine.hotkeyReleased()
        return try measure()
    }

    private func measure() throws -> PerfMeasure {
        guard let (state, slate) = clock.awaitOutcome(seconds: 120) else {
            throw PerfOutcome.timedOut
        }
        guard case .completed(let degraded) = state else {
            throw PerfOutcome.notCompleted(state)
        }
        guard !degraded else { throw PerfOutcome.degraded }
        guard let stamps = slate.stamps else { throw PerfOutcome.stampsMissing }
        return PerfMeasure(stamps)
    }
}
