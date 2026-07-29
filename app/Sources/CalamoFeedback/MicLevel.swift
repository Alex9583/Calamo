import Foundation

/// Normalizes a chunk's RMS onto 0…1 over a -50 dBFS floor, so the waveform
/// answers "am I being heard?" from the same samples the engine receives.
public enum MicLevel {
    private static let floorDb: Float = -50

    public static func normalized(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
        let rms = meanSquare.squareRoot()
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(1, max(0, (db - floorDb) / -floorDb))
    }
}
