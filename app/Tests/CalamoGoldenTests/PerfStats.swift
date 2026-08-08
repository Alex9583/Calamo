// Statistics identical to the prototype's score_e2e.py — median interpolated,
// p90 nearest-rank — so harness numbers compare to the e2e validation
// references without method drift.

/// Monotonic nanosecond stamps of one dictation, release → insertion.
struct StageStamps {
    let released: UInt64
    let transcribing: UInt64
    let cleaning: UInt64
    let inserting: UInt64
    let inserted: UInt64
}

struct PerfMeasure {
    let ffiMs: Double
    let asrMs: Double
    let cleanupMs: Double
    let spellingMs: Double
    let e2eMs: Double

    init(_ stamps: StageStamps) {
        ffiMs = Self.ms(from: stamps.released, to: stamps.transcribing)
        asrMs = Self.ms(from: stamps.transcribing, to: stamps.cleaning)
        cleanupMs = Self.ms(from: stamps.cleaning, to: stamps.inserting)
        spellingMs = Self.ms(from: stamps.inserting, to: stamps.inserted)
        e2eMs = Self.ms(from: stamps.released, to: stamps.inserted)
    }

    private static func ms(from earlier: UInt64, to later: UInt64) -> Double {
        Double(later - earlier) / 1_000_000
    }
}

enum PerfStats {
    static func median(_ values: [Double]) -> Double {
        precondition(!values.isEmpty)
        let sorted = values.sorted()
        let middle = sorted.count / 2
        guard sorted.count.isMultiple(of: 2) else { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    static func p90(_ values: [Double]) -> Double {
        precondition(!values.isEmpty)
        let sorted = values.sorted()
        let rank = Int((0.9 * Double(sorted.count)).rounded(.up))
        return sorted[max(0, rank - 1)]
    }
}
