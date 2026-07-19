import CalamoCore
import NaturalLanguage

enum UtteranceLanguage {
    // FluidAudio's batch API exposes no language identification; constrained
    // fr/en recognition on the transcript decided 15/15 corpus takes correctly
    // in the prototype. Ties (and empty text) fall back to English.
    static func detect(in text: String) -> CalamoCore.Language {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.french, .english]
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
        return (hypotheses[.french] ?? 0) > (hypotheses[.english] ?? 0) ? .french : .english
    }
}
