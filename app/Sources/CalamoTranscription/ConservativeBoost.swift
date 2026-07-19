public enum ConservativeBoost {
    public static let globalMinSimilarity: Float = 0.85

    private static let distractors: Set<String> = [
        "merge", "rebase", "release", "pipeline", "code review", "branch", "commit",
    ]

    public static func perTermMinSimilarity(forCanonical text: String) -> Float? {
        distractors.contains(text.lowercased()) ? 0.95 : nil
    }
}
