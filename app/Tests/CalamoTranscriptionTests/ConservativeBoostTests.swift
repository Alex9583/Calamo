import CalamoTranscription
import Testing

@Test func givenTheConservativePolicyWhenDerivingTheRescorerConfigThenNoPathEscapesTheGlobalGate() {
    // Given: the acoustic rescue can replace words below any similarity gate
    let gate = ConservativeBoost.globalMinSimilarity

    // When
    let config = ConservativeBoost.rescorerConfig

    // Then: rescue off, its floors pinned at the gate, env overrides pinned out
    #expect(config.spotterRescueEnabled == false)
    #expect(config.spotterRescueMinSimilarity == gate)
    #expect(config.spotterRescueMultiWordMinSimilarity == gate)
    #expect(config.shortTermCbwTaperPivot == 1)
    #expect(config.shortTermCbwTaperExponent == 2.0)
}

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
