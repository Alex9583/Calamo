// The golden suites' text metrics — the same definitions as the Rust
// harness's text_metrics module (ports of the prototype's commun.py and
// score.py); a change on one side must land on the other.
import Foundation

enum TextMetrics {
    /// Curly apostrophes, ellipses and non-breaking spaces vary freely
    /// between the models and the references; identity is judged past them.
    static func normTypo(_ text: String) -> String {
        text.replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "…", with: "...")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lowercased, unaccented, punctuation-free words — the presence alphabet.
    static func normAggressive(_ text: String) -> [String] {
        var folded = ""
        for character in normTypo(text).lowercased() {
            let c = foldAccent(character)
            folded.append(c.isLetter || c.isNumber ? c : " ")
        }
        return folded.split(separator: " ").map(String.init)
    }

    private static func foldAccent(_ c: Character) -> Character {
        switch c {
        case "à", "â", "ä": "a"
        case "é", "è", "ê", "ë": "e"
        case "î", "ï": "i"
        case "ô", "ö": "o"
        case "ù", "û", "ü": "u"
        case "ç": "c"
        default: c
        }
    }

    /// Word-boundary presence, case- and accent-insensitive: « merger » does
    /// not contain « merge ».
    static func termPresent(_ term: String, in text: String) -> Bool {
        termCount(term, in: text) > 0
    }

    /// Word-boundary occurrences on the same alphabet as termPresent.
    static func termCount(_ term: String, in text: String) -> Int {
        let term = normAggressive(term)
        let text = normAggressive(text)
        guard !term.isEmpty, term.count <= text.count else { return 0 }
        return (0...(text.count - term.count))
            .filter { Array(text[$0..<($0 + term.count)]) == term }
            .count
    }

    /// Case-sensitive word-boundary presence on typographically normalized
    /// text — the check behind the prompt's « Exact spellings » rule.
    static func termExact(_ term: String, in text: String) -> Bool {
        let term = normTypo(term)
        let text = normTypo(text)
        guard !term.isEmpty else { return false }
        var search = text.startIndex
        while let range = text.range(of: term, range: search..<text.endIndex) {
            let before = range.lowerBound == text.startIndex
                ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
            if isBoundary(before) && isBoundary(after) { return true }
            search = text.index(after: range.lowerBound)
        }
        return false
    }

    private static func isBoundary(_ c: Character?) -> Bool {
        guard let c else { return true }
        return !(c.isLetter || c.isNumber)
    }

    /// Number/filler-normalized word edit distance and reference length —
    /// the pieces of the aggregate (micro-averaged) WER.
    static func editDistance04(hypothesis: String, reference: String) -> (distance: Int, referenceCount: Int) {
        let hypothesis = tokenize04(hypothesis)
        let reference = tokenize04(reference)
        return (levenshtein(hypothesis, reference), reference.count)
    }

    /// Normalized Levenshtein similarity on the characters of number/filler-
    /// normalized tokens — the golden suites' per-take fidelity metric. Case,
    /// punctuation, digit/word number variants and hesitation fillers are out
    /// of scope by design: exact spellings have their own hard assertion.
    static func levenshteinSimilarity04(_ a: String, _ b: String) -> Double {
        let a = Array(tokenize04(a).joined(separator: " "))
        let b = Array(tokenize04(b).joined(separator: " "))
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 1.0 }
        return 1.0 - Double(levenshtein(a, b)) / Double(longest)
    }

    private static func levenshtein<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        var previous = Array(0...b.count)
        for (i, itemA) in a.enumerated() {
            var current = [i + 1]
            for (j, itemB) in b.enumerated() {
                let substitution = previous[j] + (itemA == itemB ? 0 : 1)
                current.append(min(substitution, previous[j + 1] + 1, current[j] + 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    // The corpus's normalization layer (prototype 04): the manifest writes
    // numbers as spoken words while the ASR emits digits — both sides meet here.
    private static let fillers04: Set<String> = ["euh", "um", "uh", "hum", "mmh", "hmm"]
    private static let numberMap: [String: String] = [
        "dix": "10", "quinze": "15", "quatorze": "14", "trente": "30", "cinq": "5",
        "h": "heures",
        "nine": "9", "twentieth": "20", "three": "3", "thirty": "30", "ninety": "90",
    ]
    private static let punctuation04: Set<Character> = [
        ".", ",", ";", ":", "!", "?", "«", "»", "“", "”", "\"", "(", ")", "…", "-",
    ]

    static func tokenize04(_ text: String) -> [String] {
        var stripped = ""
        for character in normTypo(text).lowercased() {
            stripped.append(punctuation04.contains(character) ? " " : character)
        }
        let tokens = splitHours(stripped)
            .split(separator: " ")
            .map { stripElision(String($0)) }
            .map { numberMap[$0] ?? $0 }
        return joinAmPm(tokens).filter { !fillers04.contains($0) }
    }

    /// « 14h30 » → « 14 heures 30 ».
    private static func splitHours(_ text: String) -> String {
        let chars = Array(text)
        var out = ""
        for (i, c) in chars.enumerated() {
            let betweenDigits = i > 0 && i + 1 < chars.count
                && chars[i - 1].isNumber && chars[i + 1].isNumber
            out.append(c == "h" && betweenDigits ? " heures " : String(c))
        }
        return out
    }

    private static func stripElision(_ token: String) -> String {
        token.count > 1 && token.hasSuffix("'") ? String(token.dropLast()) : token
    }

    /// « a.m. » survives punctuation stripping as two tokens.
    private static func joinAmPm(_ tokens: [String]) -> [String] {
        var out: [String] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if (token == "a" || token == "p"), index + 1 < tokens.count, tokens[index + 1] == "m" {
                out.append(token + "m")
                index += 2
            } else {
                out.append(token)
                index += 1
            }
        }
        return out
    }
}
