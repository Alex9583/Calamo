// The live suite's injection bound, on the manual-pass corruptions it exists
// to catch.
import CalamoCore
import Testing

struct GoldenChecksTests {
    static let template = [
        BoostEntry(canonicalText: "GitHub", aliases: ["github", "git hub"]),
        BoostEntry(canonicalText: "Calamo", aliases: []),
    ]

    @Test func givenAnUndictatedBoostedTermInTheOutputWhenBoundedThenItBreaches() {
        // Given: the live repro — « Hello, how are you? » → « Calamo, how are you? »
        let output = "Calamo, how are you?"
        let verbatim = "Hello, how are you?"

        // When
        let breaches = injectedTermBreaches(
            Self.template, id: "en-01", output: output, verbatim: verbatim)

        // Then
        #expect(breaches.count == 1)
        #expect(breaches[0].contains("Calamo"))
    }

    @Test func givenADuplicatedSpokenTermWhenBoundedThenTheExcessBreaches() {
        // Given: the live repro — « regarde le repo sur github » → « GitHub GitHub »
        let output = "GitHub GitHub"
        let verbatim = "regarde le repo sur github"

        // When
        let breaches = injectedTermBreaches(
            Self.template, id: "fr-03", output: output, verbatim: verbatim)

        // Then
        #expect(breaches.count == 1)
        #expect(breaches[0].contains("GitHub"))
    }

    @Test func givenAliasDictationLandingOnTheCanonicalWhenBoundedThenNothingBreaches() {
        // Given: the nominal case — a spoken alias may become the canonical
        let output = "Regarde le repo sur GitHub."
        let verbatim = "regarde le repo sur git hub"

        // When
        let breaches = injectedTermBreaches(
            Self.template, id: "fr-03", output: output, verbatim: verbatim)

        // Then
        #expect(breaches.isEmpty)
    }

    @Test func givenExpectedTermsWhenAbsentFromTheOutputThenTheyBreach() {
        // Given: a nominal take whose term the ASR mangled
        let output = "Regarde le repos sur JTube."

        // When
        let breaches = missingTermBreaches(["GitHub"], id: "fr-03", output: output)

        // Then
        #expect(breaches.count == 1)
        #expect(breaches[0].contains("GitHub"))
    }
}
