// Mirrors the Rust golden_guard metric tests — the two harnesses must judge
// text identically.
import Testing

struct TextMetricsTests {
    @Test func givenDigitAndSpelledNumberVariantsWhenComparedThenSimilarityIsPerfect() {
        // Given: the manifest spells numbers out while the ASR emits digits
        let spelled = "Le mardi quinze juillet à quatorze heures trente."
        let digits = "le mardi 15 juillet à 14h30"

        // Then
        #expect(TextMetrics.levenshteinSimilarity04(spelled, digits) == 1.0)
    }

    @Test func givenEnglishTimeVariantsWhenComparedThenSimilarityIsPerfect() {
        // Given
        let spelled = "Friday, June twentieth at three thirty p.m."
        let digits = "Friday June 20 at 3:30 pm"

        // Then
        #expect(TextMetrics.levenshteinSimilarity04(spelled, digits) == 1.0)
    }

    @Test func givenHesitationFillersWhenComparedThenTheyDoNotCount() {
        // Given
        let withFillers = "Euh... alors pour le, um, rapport mensuel"
        let without = "alors pour le rapport mensuel"

        // Then
        #expect(TextMetrics.levenshteinSimilarity04(withFillers, without) == 1.0)
    }

    @Test func givenADroppedClauseWhenComparedThenSimilarityFallsBelowOne() {
        // Given: fr-04's known cleanup defect, an abandoned sentence start kept
        let kept =
            "Il faut qu'on parle du budget avant vendredi. Je pense que... enfin bref, appelle-moi."
        let expected = "Il faut qu'on parle du budget avant vendredi. Bref, appelle-moi."

        // When
        let similarity = TextMetrics.levenshteinSimilarity04(kept, expected)

        // Then
        #expect(similarity < 0.95)
        #expect(similarity > 0.5)
    }

    @Test func givenEmptyTextsWhenComparedThenSimilarityIsPerfect() {
        // Then
        #expect(TextMetrics.levenshteinSimilarity04("", "") == 1.0)
        #expect(TextMetrics.levenshteinSimilarity04("Euh.", "") == 1.0)
    }

    @Test func givenExactSpellingsWhenSearchedThenOnlyCaseAndBoundaryMatchesCount() {
        // Then: case-sensitive at word boundaries
        #expect(TextMetrics.termExact("QA", in: "et si la QA est OK on push"))
        #expect(TextMetrics.termExact("pull request", in: "merger ta pull request avant la démo"))
        #expect(TextMetrics.termExact("adapter", in: "on garde l'adapter Stripe"))
        #expect(!TextMetrics.termExact("Design System", in: "le design system est cassé"))
        #expect(!TextMetrics.termExact("merge", in: "pense à merger ta pull request"))
        #expect(!TextMetrics.termExact("prod", in: "la production est en panne"))
        #expect(!TextMetrics.termExact("PR", in: "c'est pour demain"))
    }

    @Test func givenLoosePresenceWhenSearchedThenAccentAndCaseDifferencesMatch() {
        // Then: word-boundary, case- and accent-insensitive
        #expect(TextMetrics.termPresent("design system", in: "le Design System est cassé"))
        #expect(!TextMetrics.termPresent("merge", in: "pense à merger ta pull request"))
        #expect(TextMetrics.termPresent("reunion", in: "la réunion de demain"))
    }

    @Test func givenRepeatedOccurrencesWhenCountedThenEachBoundaryMatchCounts() {
        // Then: same alphabet as termPresent, occurrences instead of presence
        #expect(TextMetrics.termCount("GitHub", in: "GitHub GitHub") == 2)
        #expect(TextMetrics.termCount("github", in: "regarde le repo sur GitHub") == 1)
        #expect(TextMetrics.termCount("merge", in: "pense à merger ta pull request") == 0)
        #expect(TextMetrics.termCount("git hub", in: "le git hub de l'équipe") == 1)
        #expect(TextMetrics.termCount("Calamo", in: "") == 0)
    }

    @Test func givenIdenticalTextsWhenMeasuredThenEditDistanceIsZero() {
        // Given
        let reference = "Hi team, the deployment is scheduled for tomorrow at nine a.m."

        // When
        let (distance, count) = TextMetrics.editDistance04(
            hypothesis: "hi team the deployment is scheduled for tomorrow at 9 am",
            reference: reference)

        // Then
        #expect(distance == 0)
        #expect(count == 11)
    }
}
