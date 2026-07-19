import CalamoTranscription
import Testing

@Test func givenAnIdentifiedDistractorWhenDerivingItsBoostThresholdThenItIsTightenedTo095() {
    // Given: the common words the prototype saw corrupt transcripts
    let distractors = ["merge", "rebase", "release", "pipeline", "code review", "branch", "commit"]

    // When
    let thresholds = distractors.map { ConservativeBoost.perTermMinSimilarity(forCanonical: $0) }

    // Then
    #expect(thresholds == Array(repeating: 0.95, count: distractors.count))
}

@Test func givenARegularDictionaryTermWhenDerivingItsBoostThresholdThenTheGlobalThresholdApplies() {
    // Given
    let regulars = ["GitHub", "feature flag", "Stripe", "backlog"]

    // When
    let thresholds = regulars.map { ConservativeBoost.perTermMinSimilarity(forCanonical: $0) }

    // Then
    #expect(thresholds == Array(repeating: nil, count: regulars.count))
    #expect(ConservativeBoost.globalMinSimilarity == 0.85)
}

@Test func givenADistractorSpelledWithCapitalsWhenDerivingItsBoostThresholdThenItIsStillTightened() {
    // Given: a Dictionary may capitalize an entry without changing what it is
    let canonical = "Release"

    // When
    let threshold = ConservativeBoost.perTermMinSimilarity(forCanonical: canonical)

    // Then
    #expect(threshold == 0.95)
}
