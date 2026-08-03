import FluidAudio

public enum ConservativeBoost {
    public static let globalMinSimilarity: Float = 0.85

    private static let distractors: Set<String> = [
        "merge", "rebase", "release", "pipeline", "code review", "branch", "commit",
    ]

    public static func perTermMinSimilarity(forCanonical text: String) -> Float? {
        distractors.contains(text.lowercased()) ? 0.95 : nil
    }

    /// The default config's spotter-anchored rescue replaces words on acoustic
    /// evidence alone — no similarity gate — and only runs for dictionaries of
    /// ≤ 10 entries, so small live dictionaries corrupted normal speech while
    /// the large golden boost list never could. Every value is explicit because
    /// several defaults read FLUID_* env overrides.
    public static var rescorerConfig: VocabularyRescorer.Config {
        VocabularyRescorer.Config(
            shortTermCbwTaperPivot: 1,
            shortTermCbwTaperExponent: 2.0,
            spotterRescueMinSimilarity: globalMinSimilarity,
            spotterRescueMultiWordMinSimilarity: globalMinSimilarity,
            spotterRescueEnabled: false
        )
    }
}
