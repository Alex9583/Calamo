// The hard per-take assertions both audio-fed suites share.
import CalamoCore

func languageCode(_ language: CalamoCore.Language) -> String {
    switch language {
    case .french: "fr"
    case .english: "en"
    }
}

func languageBreach(id: String, detected: String, expected: String?, in text: String) -> [String] {
    guard detected != expected else { return [] }
    return ["\(id): language \(detected), expected \(expected ?? "?") in: \(text)"]
}

/// A never-spoken term may only appear if the take itself dictated it.
func neverSpokenBreaches(_ terms: [String], id: String, output: String, verbatim: String)
    -> [String]
{
    terms
        .filter {
            TextMetrics.termPresent($0, in: output) && !TextMetrics.termPresent($0, in: verbatim)
        }
        .map { "\(id): never-spoken term « \($0) » in: \(output)" }
}
