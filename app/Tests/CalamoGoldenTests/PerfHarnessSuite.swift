// Perf harness — the latency milestone rite. Replays the reference corpus
// through the real DictationEngine warm, in one process, and asserts the
// spec budget: p90 < 2 s release → insertion for ~10 s dictations. Latency
// is deliberately out of the golden suites; this harness is the authority.
// On demand only (CALAMO_PERF=1), reference machine, never CI — trigger rule
// and regression policy: docs/perf-harness.md.
import FluidAudio
import Foundation
import Testing

enum PerfGate {
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["CALAMO_PERF"] == "1"
    }

    static var passes: Int {
        Int(ProcessInfo.processInfo.environment["CALAMO_PERF_PASSES"] ?? "") ?? 3
    }
}

struct PerfHarnessSuite {
    struct Take {
        let id: String
        let seconds: Double
        let samples: [Float]
    }

    struct Measured {
        let take: Take
        let measure: PerfMeasure
    }

    private let budgetMs = 2000.0
    /// The reference "~10 s" dictation band of the e2e validation.
    private let referenceBand = 9.0...13.0
    private let warmupId = "fr-02"

    @Test(.enabled(if: PerfGate.isRequested))
    func givenAWarmEngineWhenTheCorpusReplaysThenReleaseToInsertionP90HoldsTheBudget() throws {
        GoldenGate.modelLock.lock()
        defer { GoldenGate.modelLock.unlock() }

        // Given: the corpus in memory, the real chain loaded then warmed by
        // one excluded dictation (first call pays cold costs)
        let contract: TranscriptionContract = try GoldenFixtures.decode(
            "transcription-contract.json")
        let takes = try loadedTakes(contract)
        let stack = try PerfStack.load(dictionary: contract.dictionaryToml())
        print("[perf] models resident: \(memoryLine())")
        let warmup = try stack.dictate(try #require(takes.first { $0.id == warmupId }).samples)
        print("[perf] warmup \(warmupId) (excluded)  \(measureLine(warmup))")

        // When: every take dictated warm, in corpus order, several passes
        let measures = try measuredPasses(stack, takes)

        // Then: the full report, then the hard budget
        let failures = reportedBreaches(measures)
        #expect(failures.isEmpty, "\n\(failures.joined(separator: "\n"))")
    }

    private func loadedTakes(_ contract: TranscriptionContract) throws -> [Take] {
        let converter = AudioConverter()
        return try contract.takes.map { vector in
            let samples = try converter.resampleAudioFile(
                path: GoldenFixtures.audioURL(vector.id, in: contract).path)
            return Take(id: vector.id, seconds: Double(samples.count) / 16000, samples: samples)
        }
    }

    private func measuredPasses(_ stack: PerfStack, _ takes: [Take]) throws -> [Measured] {
        var measures: [Measured] = []
        for pass in 1...PerfGate.passes {
            for take in takes {
                let measure = try stack.dictate(take.samples)
                print("[perf] p\(pass)/\(PerfGate.passes) \(take.id)  \(measureLine(measure))")
                measures.append(Measured(take: take, measure: measure))
            }
        }
        return measures
    }

    private func reportedBreaches(_ measures: [Measured]) -> [String] {
        let e2e = measures.map(\.measure.e2eMs)
        let reference = measures
            .filter { referenceBand.contains($0.take.seconds) }
            .map(\.measure.e2eMs)
        let takeCount = Set(measures.map(\.take.id)).count
        print("[perf] === warm report: \(e2e.count) dictations "
            + "(\(takeCount) takes × \(PerfGate.passes) passes) ===")
        stageRows(measures).forEach { print(statsLine($0.label, $0.values)) }
        if !reference.isEmpty {
            print(statsLine("e2e ~10 s (9–13 s, n=\(reference.count))", reference))
        }
        print("[perf] RAM peak: \(memoryLine())")
        return budgetBreaches(all: e2e, reference: reference)
    }

    private func stageRows(_ measures: [Measured]) -> [(label: String, values: [Double])] {
        [
            ("e2e", measures.map(\.measure.e2eMs)),
            ("asr", measures.map(\.measure.asrMs)),
            ("cleanup", measures.map(\.measure.cleanupMs)),
            ("spelling", measures.map(\.measure.spellingMs)),
            ("ffi", measures.map(\.measure.ffiMs)),
        ]
    }

    private func budgetBreaches(all: [Double], reference: [Double]) -> [String] {
        guard !reference.isEmpty else {
            return ["no takes in the 9–13 s band: the ~10 s budget went unassessed"]
        }
        let breaches = [
            ("all takes", PerfStats.p90(all)),
            ("9–13 s takes", PerfStats.p90(reference)),
        ].filter { $0.1 >= budgetMs }
        let verdict = breaches.isEmpty ? "PASS" : "FAIL"
        print(String(
            format: "[perf] budget p90 < %.0f ms: all %.0f, 9–13 s %.0f — %@",
            budgetMs, PerfStats.p90(all), PerfStats.p90(reference), verdict))
        return breaches.map {
            String(format: "e2e p90 %.0f ms over %@ breaks the %.0f ms budget", $1, $0, budgetMs)
        }
    }

    private func measureLine(_ m: PerfMeasure) -> String {
        String(
            format: "e2e %4.0f ms (ffi %.0f + asr %.0f + cleanup %.0f + spelling %.0f)",
            m.e2eMs, m.ffiMs, m.asrMs, m.cleanupMs, m.spellingMs)
    }

    private func statsLine(_ label: String, _ values: [Double]) -> String {
        String(
            format: "[perf] %@  median %4.0f  p90 %4.0f  max %4.0f ms",
            label.padding(toLength: max(label.count, 8), withPad: " ", startingAt: 0),
            PerfStats.median(values), PerfStats.p90(values), values.max() ?? 0)
    }

    private func memoryLine() -> String {
        guard let memory = MemoryFootprint.sample() else { return "phys_footprint unavailable" }
        return String(
            format: "phys_footprint %.0f MB (lifetime peak %.0f MB)",
            memory.footprintMB, memory.lifetimePeakMB)
    }
}
